import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../profile/controller/profile_controller.dart';

class PayslipPdfHelper {
  static Future<void> printPayslipPdf(
    String month, {
    String? employeeId,
    double? gross,
    double? deductions,
  }) async {
    final pdfBytes = await generatePayslipPdfBytes(
      month,
      employeeId: employeeId,
      gross: gross,
      deductions: deductions,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Payment_Slip_${month.replaceAll(' ', '_')}.pdf',
    );
  }

  static Future<Uint8List> generatePayslipPdfBytes(
    String month, {
    String? employeeId,
    double? gross,
    double? deductions,
    double? elBalance,
    double? clBalance,
    double? hplBalance,
  }) async {
    final doc = pw.Document();

    pw.Font fontRegular;
    pw.Font fontBold;
    try {
      fontRegular = await PdfGoogleFonts.hindRegular();
      fontBold = await PdfGoogleFonts.hindBold();
    } catch (_) {
      fontRegular = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
    }

    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
    );

    // Dynamic Employee Resolution with fallback to Emp 4428 real values from Image 2
    final cleanId = (employeeId ?? (ProfileController.rawEmployees.isNotEmpty ? ProfileController.rawEmployees.first['empNo']?.toString() : '') ?? '').trim().replaceAll(RegExp('^0+'), '');
    final Map<String, dynamic> raw = ProfileController.rawEmployees.firstWhere(
      (e) => e['empNo'] == cleanId,
      orElse: () => ProfileController.rawEmployees.isNotEmpty ? ProfileController.rawEmployees.first : <String, dynamic>{},
    );

    final String empName = raw['name'] ?? 'Employee';
    final String empPno = raw['empNo'] != null ? raw['empNo'].toString().padLeft(8, '0') : (cleanId.isNotEmpty ? cleanId.padLeft(8, '0') : '00000000');
    final String location = raw['subarea'] ?? '';
    final String department = raw['dept'] ?? '';
    final String grade = raw['payscale'] ?? '';
    final String empGrp = raw['group'] ?? '';
    final String empSubgrp = raw['subgroupText'] ?? '';
    final String designation = raw['position'] ?? '';
    final String pfNo = raw['pfNo'] ?? '';
    final String formBNo = raw['fb'] ?? '';
    final String panNo = raw['pan'] ?? '';
    final String bankAcc = raw['bankAcc'] ?? '';

    final double basicVal = double.tryParse(raw['basic'].toString().replaceAll(',', '')) ?? 0.0;
    final double grossVal = gross ?? (double.tryParse(raw['gross'].toString().replaceAll(',', '')) ?? 0.0);
    final double deductionsVal = deductions ?? 44678.00;
    final double netVal = grossVal - deductionsVal;

    final double daVal = 47992.00;
    final double hraVal = 17742.00;
    final double bfDaVal = 621.00;
    final double otherPerksVal = 31048.50;

    final double pfVal = 16404.00;
    final double ptVal = 200.00;
    final double itVal = 20750.00;
    final double cfPfVal = 74.00;
    final double creditSocVal = 7000.00;
    final double furnRecVal = 100.00;
    final double meaSubVal = 100.00;
    final double benevolentVal = 50.00;

    final format = NumberFormat.currency(locale: 'HI', symbol: '', decimalDigits: 2);

    // Helper for table cells
    pw.Widget cellText(String text, {bool bold = false, double size = 8, PdfColor? color, pw.Alignment alignment = pw.Alignment.centerLeft}) {
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
              // Header
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

              // Employee Info Grid
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
                    cellText(empName),
                    cellText('Location\nकार्यस्थल', bold: true),
                    cellText(location),
                    cellText('Grade\nवेतनमान', bold: true),
                    cellText(grade),
                  ]),
                  pw.TableRow(children: [
                    cellText('Personnel No.\nकर्मचारी नंबर', bold: true),
                    cellText(empPno),
                    cellText('Department\nविभाग', bold: true),
                    cellText(department),
                    cellText('Emp Grp\nकर्मचारी समूह', bold: true),
                    cellText(empGrp),
                  ]),
                  pw.TableRow(children: [
                    cellText('Period\nअवधि', bold: true),
                    cellText('01.05.2026-31.05.2026'),
                    cellText('PF No\nभविष्य निधि नंबर', bold: true),
                    cellText(pfNo),
                    cellText('Emp Subgrp\nकर्मचारी उपसमूह', bold: true),
                    cellText(empSubgrp),
                  ]),
                  pw.TableRow(children: [
                    cellText('Pan No\nपैन नंबर', bold: true),
                    cellText(panNo),
                    cellText('Form B No\nफॉर्म बी. नंबर', bold: true),
                    cellText(formBNo),
                    cellText('Designation\nपदनाम', bold: true),
                    cellText(designation),
                  ]),
                ],
              ),
              pw.SizedBox(height: 6),

              // Bank Info & Summary Table
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
                      cellText(bankAcc, alignment: pw.Alignment.center),
                      cellText(format.format(basicVal), alignment: pw.Alignment.center),
                      cellText(format.format(grossVal), alignment: pw.Alignment.center),
                      cellText(format.format(deductionsVal), alignment: pw.Alignment.center),
                      cellText(format.format(netVal), alignment: pw.Alignment.center),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 6),

              // Earnings & Deductions Details Table
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
                    cellText(format.format(basicVal), alignment: pw.Alignment.centerRight),
                    cellText('Ee PF contribution\nकर्मचारी PF अंशदान'),
                    cellText(format.format(pfVal), alignment: pw.Alignment.centerRight),
                  ]),
                  pw.TableRow(children: [
                    cellText('Dearness Allow - Exe & NE\nमहंगाई भत्ता-दिव्या'),
                    cellText(format.format(daVal), alignment: pw.Alignment.centerRight),
                    cellText('Prof Tax - split period\nवृत्ति कर - विभाजन अवधि'),
                    cellText(format.format(ptVal), alignment: pw.Alignment.centerRight),
                  ]),
                  pw.TableRow(children: [
                    cellText('House Rent Allow E&NE\nमकान किराया भत्ता'),
                    cellText(format.format(hraVal), alignment: pw.Alignment.centerRight),
                    cellText('Income Tax\nआयकर'),
                    cellText(format.format(itVal), alignment: pw.Alignment.centerRight),
                  ]),
                  pw.TableRow(children: [
                    cellText('BFDearness Allow - Exe &N\nबीएफ महंगाई भत्ता'),
                    cellText(format.format(bfDaVal), alignment: pw.Alignment.centerRight),
                    cellText('CF Pf monthly\nCF मासिक भविष्य निधि'),
                    cellText(format.format(cfPfVal), alignment: pw.Alignment.centerRight),
                  ]),
                  pw.TableRow(children: [
                    cellText('Other Perks\nअन्य भत्ते'),
                    cellText(format.format(otherPerksVal), alignment: pw.Alignment.centerRight),
                    cellText('Credit Society Share\nक्रेडिट सोसायटी शेयर'),
                    cellText(format.format(creditSocVal), alignment: pw.Alignment.centerRight),
                  ]),
                  pw.TableRow(children: [
                    cellText(''),
                    cellText(''),
                    cellText('Furn & Fixture Recovery\nफर्निचर और फिक्सचर रिकव'),
                    cellText(format.format(furnRecVal), alignment: pw.Alignment.centerRight),
                  ]),
                  pw.TableRow(children: [
                    cellText(''),
                    cellText(''),
                    cellText('MEA Subscription fees\nएमईए सदस्यता शुल्क'),
                    cellText(format.format(meaSubVal), alignment: pw.Alignment.centerRight),
                  ]),
                  pw.TableRow(children: [
                    cellText(''),
                    cellText(''),
                    cellText('Benevolent Fund\nपरोपकार निधि'),
                    cellText(format.format(benevolentVal), alignment: pw.Alignment.centerRight),
                  ]),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      cellText('Total Earnings', bold: true),
                      cellText(format.format(grossVal), bold: true, alignment: pw.Alignment.centerRight),
                      cellText('Total Deductions', bold: true),
                      cellText(format.format(deductionsVal), bold: true, alignment: pw.Alignment.centerRight),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 4),

              // Take Home Pay Summary Box
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
                    pw.Text(format.format(netVal), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),

              // Form 16 Summary & Chapter VIA Deductions Side-by-Side
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
                          cellText('2,240,451.00', alignment: pw.Alignment.centerRight),
                        ]),
                        pw.TableRow(children: [
                          cellText('Balance'),
                          cellText('2,240,451.00', alignment: pw.Alignment.centerRight),
                        ]),
                        pw.TableRow(children: [
                          cellText('Incm under Hd Salary'),
                          cellText('2,240,451.00', alignment: pw.Alignment.centerRight),
                        ]),
                        pw.TableRow(children: [
                          cellText('Gross Tot Income'),
                          cellText('2,240,451.00', alignment: pw.Alignment.centerRight),
                        ]),
                        pw.TableRow(children: [
                          cellText('Total Income'),
                          cellText('2,240,451.00', alignment: pw.Alignment.centerRight),
                        ]),
                        pw.TableRow(children: [
                          cellText('Tax payable and surcharge'),
                          cellText('426,021.00', alignment: pw.Alignment.centerRight),
                        ]),
                        pw.TableRow(children: [
                          cellText('Income Tax'),
                          cellText('20,750.00', alignment: pw.Alignment.centerRight),
                        ]),
                        pw.TableRow(children: [
                          cellText('Balance tax(payable/refundable)'),
                          cellText('405,271.00', alignment: pw.Alignment.centerRight),
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
                          cellText('Section 80C'),
                          cellText('150,000.00', alignment: pw.Alignment.centerRight),
                          cellText('150,000.00', alignment: pw.Alignment.centerRight),
                        ]),
                        pw.TableRow(children: [
                          cellText('Section 80D'),
                          cellText('25,000.00', alignment: pw.Alignment.centerRight),
                          cellText('25,000.00', alignment: pw.Alignment.centerRight),
                        ]),
                        pw.TableRow(children: [
                          cellText('Section 80CCD(1B)'),
                          cellText('50,000.00', alignment: pw.Alignment.centerRight),
                          cellText('50,000.00', alignment: pw.Alignment.centerRight),
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

              // Leave Details Row
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
                      cellText('Balance', alignment: pw.Alignment.center),
                      cellText((elBalance ?? 0.0).toStringAsFixed(2), alignment: pw.Alignment.center),
                      cellText((clBalance ?? 0.0).toStringAsFixed(2), alignment: pw.Alignment.center),
                      cellText((hplBalance ?? 0.0).toStringAsFixed(2), alignment: pw.Alignment.center),
                      cellText('0.00', alignment: pw.Alignment.center),
                      cellText('2.00', alignment: pw.Alignment.center),
                      cellText('0.00', alignment: pw.Alignment.center),
                      cellText('30', alignment: pw.Alignment.center),
                      cellText('30.00', alignment: pw.Alignment.center),
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
}
