import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

Future<void> main() async {
  final outDir = Directory('scratch/generated_sap_pdfs');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  final files = [
    {'name': '4428_05_2026.pdf', 'emp': '4428', 'period': '01.05.2026-31.05.2026', 'month': 'May 2026'},
    {'name': '4428_06_2026.pdf', 'emp': '4428', 'period': '01.06.2026-30.06.2026', 'month': 'June 2026'},
    {'name': '4428_07_2026.pdf', 'emp': '4428', 'period': '01.07.2026-31.07.2026', 'month': 'July 2026'},
    {'name': '4677_05_2026.pdf', 'emp': '4677', 'period': '01.05.2026-31.05.2026', 'month': 'May 2026'},
    {'name': '4677_06_2026.pdf', 'emp': '4677', 'period': '01.06.2026-30.06.2026', 'month': 'June 2026'},
    {'name': '4677_07_2026.pdf', 'emp': '4677', 'period': '01.07.2026-31.07.2026', 'month': 'July 2026'},
  ];

  for (final f in files) {
    final pdfBytes = await generateFullSapPdfBytes(
      empNo: f['emp']!,
      periodStr: f['period']!,
      monthStr: f['month']!,
    );
    final file = File('${outDir.path}/${f['name']}');
    await file.writeAsBytes(pdfBytes);
    print('✅ Generated exact MOIL SAP PDF: ${f['name']} (${pdfBytes.length} bytes)');
  }

  print('🎉 All SAP PDF files generated successfully!');
  exit(0);
}

Future<List<int>> generateFullSapPdfBytes({
  required String empNo,
  required String periodStr,
  required String monthStr,
}) async {
  final doc = pw.Document();
  final fontRegular = pw.Font.helvetica();
  final fontBold = pw.Font.helveticaBold();

  final theme = pw.ThemeData.withFont(
    base: fontRegular,
    bold: fontBold,
  );

  pw.Widget cellText(
    String text, {
    bool bold = false,
    double size = 8,
    PdfColor? color,
    pw.Alignment alignment = pw.Alignment.centerLeft,
  }) {
    return pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: size,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColors.black,
        ),
      ),
    );
  }

  doc.addPage(
    pw.Page(
      theme: theme,
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header (Logo left, Payment Slip right)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      width: 32,
                      height: 32,
                      decoration: const pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFF0F2080),
                        shape: pw.BoxShape.circle,
                      ),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'मॉयल\nMOIL',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 6,
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'MOIL LIMITED',
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0F2080)),
                        ),
                        pw.Text(
                          'मॉयल लिमिटेड',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Payment Slip',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                    ),
                    pw.Text(
                      'वेतन पर्ची',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 8),

            // Employee Info Grid matching Image 3 exact format
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(100),
                1: const pw.FlexColumnWidth(),
                2: const pw.FixedColumnWidth(100),
                3: const pw.FlexColumnWidth(),
                4: const pw.FixedColumnWidth(100),
                5: const pw.FlexColumnWidth(),
              },
              children: [
                pw.TableRow(children: [
                  cellText('Emp Name\nनाम', bold: true),
                  cellText('B.C.N. Gautam'),
                  cellText('Location\nकार्यस्थल', bold: true),
                  cellText('Head Office Nag'),
                  cellText('Grade\nवेतनमान', bold: true),
                  cellText('80000-220000'),
                ]),
                pw.TableRow(children: [
                  cellText('Personnel No.\nकर्मचारी नंबर', bold: true),
                  cellText(empNo.padLeft(8, '0')),
                  cellText('Department\nविभाग', bold: true),
                  cellText('System'),
                  cellText('Emp Grp\nकर्मचारी समूह', bold: true),
                  cellText('Executive'),
                ]),
                pw.TableRow(children: [
                  cellText('Period\nअवधि', bold: true),
                  cellText(periodStr),
                  cellText('PF No\nभविष्य निधि नंबर', bold: true),
                  cellText('NG/NAG/3600/4755'),
                  cellText('Emp Subgrp\nकर्मचारी उपसमूह', bold: true),
                  cellText('Asst. Gen. Manager'),
                ]),
                pw.TableRow(children: [
                  cellText('Pan No\nपैन नंबर', bold: true),
                  cellText('AIMPG8474A'),
                  cellText('Form B No\nफॉर्म बी. नंबर', bold: true),
                  cellText('02260'),
                  cellText('Designation\nपदनाम', bold: true),
                  cellText('Assistant General Manager-System'),
                ]),
              ],
            ),
            pw.SizedBox(height: 6),

            // Bank Info & Summary Table matching Image 3
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(1.2),
                3: const pw.FlexColumnWidth(1.2),
                4: const pw.FlexColumnWidth(1.2),
                5: const pw.FlexColumnWidth(1.2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    cellText('Bank Name', bold: true, alignment: pw.Alignment.center),
                    cellText('Account No', bold: true, alignment: pw.Alignment.center),
                    cellText('Basic', bold: true, alignment: pw.Alignment.center),
                    cellText('Earnings', bold: true, alignment: pw.Alignment.center),
                    cellText('Deductions', bold: true, alignment: pw.Alignment.center),
                    cellText('Net Pay', bold: true, alignment: pw.Alignment.center),
                  ],
                ),
                pw.TableRow(
                  children: [
                    cellText('STATE BANK OF INDIA', alignment: pw.Alignment.center),
                    cellText('20529486466', alignment: pw.Alignment.center),
                    cellText('91,380.00', alignment: pw.Alignment.center),
                    cellText('192,538.00', alignment: pw.Alignment.center),
                    cellText('46,943.00', alignment: pw.Alignment.center),
                    cellText('145,595.00', alignment: pw.Alignment.center),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 6),

            // Earnings & Deductions Details Table matching Image 3
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.5),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(2.5),
                3: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    cellText('Earnings\nअर्जन', bold: true, alignment: pw.Alignment.center),
                    cellText('', bold: true),
                    cellText('Deductions\nकटौतियाँ', bold: true, alignment: pw.Alignment.center),
                    cellText('', bold: true),
                  ],
                ),
                pw.TableRow(children: [
                  cellText('Basic Pay - Exe & NE\nमूल वेतन'),
                  cellText('91,380.00', alignment: pw.Alignment.centerRight),
                  cellText('Ee PF contribution\nकर्मचारी PF अंशदान'),
                  cellText('17,073.00', alignment: pw.Alignment.centerRight),
                ]),
                pw.TableRow(children: [
                  cellText('Dearness Allow - Exe & NE\nमहंगाई भत्ता-दिव्या'),
                  cellText('50,899.00', alignment: pw.Alignment.centerRight),
                  cellText('Prof Tax - split period\nवृत्ति कर - विभाजन अवधि'),
                  cellText('200.00', alignment: pw.Alignment.centerRight),
                ]),
                pw.TableRow(children: [
                  cellText('House Rent Allow E&NE\nमकान किराया भत्ता'),
                  cellText('18,276.00', alignment: pw.Alignment.centerRight),
                  cellText('Income Tax\nआयकर'),
                  cellText('22,420.00', alignment: pw.Alignment.centerRight),
                ]),
                pw.TableRow(children: [
                  cellText('Other Perks\nअन्य भत्ते'),
                  cellText('31,983.00', alignment: pw.Alignment.centerRight),
                  cellText('Credit Society Share\nक्रेडिट सोसायटी शेयर'),
                  cellText('7,000.00', alignment: pw.Alignment.centerRight),
                ]),
                pw.TableRow(children: [
                  cellText(''),
                  cellText(''),
                  cellText('Furn & Fixture Recovery\nफर्निचर और फिक्सचर रिकव'),
                  cellText('100.00', alignment: pw.Alignment.centerRight),
                ]),
                pw.TableRow(children: [
                  cellText(''),
                  cellText(''),
                  cellText('MEA Subscription fees\nएमईए सदस्यता शुल्क'),
                  cellText('100.00', alignment: pw.Alignment.centerRight),
                ]),
                pw.TableRow(children: [
                  cellText(''),
                  cellText(''),
                  cellText('Benevolent Fund\nपरोपकार निधि'),
                  cellText('50.00', alignment: pw.Alignment.centerRight),
                ]),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    cellText('Total', bold: true),
                    cellText('192,538.00', bold: true, alignment: pw.Alignment.centerRight),
                    cellText('Total', bold: true),
                    cellText('46,943.00', bold: true, alignment: pw.Alignment.centerRight),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 4),

            // Take Home Pay Summary Box matching Image 3
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 0.5),
                color: PdfColors.grey300,
              ),
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Take Home Pay', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.Text('145,595.00', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ],
              ),
            ),
            pw.SizedBox(height: 6),

            // Form 16 Summary & Chapter VIA Deductions Side-by-Side matching Image 3
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Form 16 Summary
                pw.Expanded(
                  flex: 1,
                  child: pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2),
                      1: const pw.FlexColumnWidth(1),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          cellText('Form 16 Summary', bold: true),
                          cellText('', bold: true),
                        ],
                      ),
                      pw.TableRow(children: [
                        cellText('Gross Salary'),
                        cellText('2,303,239.50', alignment: pw.Alignment.centerRight),
                      ]),
                      pw.TableRow(children: [
                        cellText('Balance'),
                        cellText('2,303,240.00', alignment: pw.Alignment.centerRight),
                      ]),
                      pw.TableRow(children: [
                        cellText('Incm under Hd Salary'),
                        cellText('2,303,240.00', alignment: pw.Alignment.centerRight),
                      ]),
                      pw.TableRow(children: [
                        cellText('Gross Tot Income'),
                        cellText('2,303,240.00', alignment: pw.Alignment.centerRight),
                      ]),
                      pw.TableRow(children: [
                        cellText('Total Income'),
                        cellText('2,303,240.00', alignment: pw.Alignment.centerRight),
                      ]),
                      pw.TableRow(children: [
                        cellText('Tax payable and surcharge'),
                        cellText('445,611.00', alignment: pw.Alignment.centerRight),
                      ]),
                      pw.TableRow(children: [
                        cellText('Income Tax'),
                        cellText('22,420.00', alignment: pw.Alignment.centerRight),
                      ]),
                      pw.TableRow(children: [
                        cellText('Balance tax(payable/refundable)'),
                        cellText('381,691.00', alignment: pw.Alignment.centerRight),
                      ]),
                    ],
                  ),
                ),
                pw.SizedBox(width: 6),

                // Chapter VIA Deductions
                pw.Expanded(
                  flex: 1,
                  child: pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1.5),
                      1: const pw.FlexColumnWidth(1),
                      2: const pw.FlexColumnWidth(1),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          cellText('Chapter VIA Deductions', bold: true),
                          cellText('Invst. amt', bold: true),
                          cellText('Effect Exm.', bold: true),
                        ],
                      ),
                      pw.TableRow(children: [
                        cellText(''),
                        cellText(''),
                        cellText(''),
                      ]),
                      pw.TableRow(children: [
                        cellText(''),
                        cellText(''),
                        cellText(''),
                      ]),
                      pw.TableRow(children: [
                        cellText(''),
                        cellText(''),
                        cellText(''),
                      ]),
                      pw.TableRow(children: [
                        cellText(''),
                        cellText(''),
                        cellText(''),
                      ]),
                      pw.TableRow(children: [
                        cellText(''),
                        cellText(''),
                        cellText(''),
                      ]),
                      pw.TableRow(children: [
                        cellText(''),
                        cellText(''),
                        cellText(''),
                      ]),
                      pw.TableRow(children: [
                        cellText(''),
                        cellText(''),
                        cellText(''),
                      ]),
                      pw.TableRow(children: [
                        cellText(''),
                        cellText(''),
                        cellText(''),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),

            // Leave Details Row matching Image 3 exact figures
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1.2),
                5: const pw.FlexColumnWidth(1),
                6: const pw.FlexColumnWidth(1),
                7: const pw.FlexColumnWidth(1),
                8: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    cellText('Leave Details\nहाजरी', bold: true, alignment: pw.Alignment.center),
                    cellText('E.L.\n अर्जित छुट्टी', bold: true, alignment: pw.Alignment.center),
                    cellText('C.L.\nआकस्मिक छुट्टी', bold: true, alignment: pw.Alignment.center),
                    cellText('H.P.L.\nअर्ध वेतन छुट्टी', bold: true, alignment: pw.Alignment.center),
                    cellText('C.H.P.L.\nसी.एच.पी.एल.', bold: true, alignment: pw.Alignment.center),
                    cellText('O.L.\nवैकल्पिक छुट्टी', bold: true, alignment: pw.Alignment.center),
                    cellText('L.W.P.\nविन वेतन छुट्टी', bold: true, alignment: pw.Alignment.center),
                    cellText('ATTEND\nहाजरी', bold: true, alignment: pw.Alignment.center),
                    cellText('Total\nकुल', bold: true, alignment: pw.Alignment.center),
                  ],
                ),
                pw.TableRow(
                  children: [
                    cellText('', alignment: pw.Alignment.center),
                    cellText('266.00', alignment: pw.Alignment.center),
                    cellText('6.50', alignment: pw.Alignment.center),
                    cellText('315.00', alignment: pw.Alignment.center),
                    cellText('0.00', alignment: pw.Alignment.center),
                    cellText('2.00', alignment: pw.Alignment.center),
                    cellText('0.00', alignment: pw.Alignment.center),
                    cellText('31', alignment: pw.Alignment.center),
                    cellText('31.00', alignment: pw.Alignment.center),
                  ],
                ),
                pw.TableRow(
                  children: [
                    cellText('Balance', alignment: pw.Alignment.center),
                    cellText('266.00', alignment: pw.Alignment.center),
                    cellText('6.50', alignment: pw.Alignment.center),
                    cellText('315.00', alignment: pw.Alignment.center),
                    cellText('0.00', alignment: pw.Alignment.center),
                    cellText('2.00', alignment: pw.Alignment.center),
                    cellText('0.00', alignment: pw.Alignment.center),
                    cellText('31', alignment: pw.Alignment.center),
                    cellText('31.00', alignment: pw.Alignment.center),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 8),

            // Footer Note
            pw.Center(
              child: pw.Text(
                'This is a system generated pay-slip and requires no signature',
                style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600),
              ),
            ),
          ],
        );
      },
    ),
  );

  return doc.save();
}
