import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

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
    final mainImg = pw.MemoryImage(image);

    // ---------- LOAD LOGO (FAIL-SAFE) ----------
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

        // ---------- TEXT FOOTER ----------
        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              "OptiFocus",
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
          );
        },

        build: (context) => [
          // ---------- LOGO + COPYRIGHT ----------
          if (logoImg != null) ...[
            pw.Center(
              child: pw.Image(
                logoImg,
                height: 120,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text(
                "© 2026 OptiFocus. All rights reserved.",
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
            ),
            pw.SizedBox(height: 14),
          ],

          // ---------- TITLE ----------
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

          // ---------- IMAGE ----------
          pw.Container(
            height: 200,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
            ),
            child: pw.Image(
              mainImg,
              fit: pw.BoxFit.contain,
            ),
          ),

          pw.SizedBox(height: 24),

          // ---------- AUTO MEASUREMENTS ----------
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _table(
                  title: "PD Measurements (Auto)",
                  rows: {
                    "PD Left (mm)": pdLeft,
                    "PD Right (mm)": pdRight,
                    "PD Total (mm)": pdTotal,
                  },
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: _table(
                  title: "Frame Measurements (Auto)",
                  rows: {
                    "A (mm)": A,
                    "B (mm)": B,
                    "DBL (mm)": DBL,
                  },
                ),
              ),
            ],
          ),

          // ---------- MANUAL MEASUREMENTS ----------
          if (manualValues != null) ...[
            pw.SizedBox(height: 32),
            pw.Text(
              "Manual Measurements",
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _table(
                    title: "PD (Manual)",
                    rows: {
                     
                      "PD Right (mm)": manualValues["PD Right (mm)"]!,
                      "PD Left (mm)": manualValues["PD Left (mm)"]!,
                      "PD Total (mm)": manualValues["PD Total (mm)"]!,
                    },
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  child: _table(
                    title: "Frame (Manual)",
                    rows: {
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

  // ---------- TABLE ----------
  static pw.Widget _table({
    required String title,
    required Map<String, double> rows,
  }) {
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
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(
            color: PdfColors.grey400,
            width: 0.8,
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(2),
          },
          children: rows.entries.map(
            (e) => pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: pw.Text(e.key),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
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