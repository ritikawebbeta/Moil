import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../model/employee_model.dart';

class ProfilePdfHelper {
  static Future<void> printEmployeeProfilePdf(EmployeeModel emp) async {
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

    // Helper for table cells
    pw.Widget cellText(String text, {bool bold = false, double size = 9, PdfColor? color}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
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

    pw.ImageProvider? avatarImg;
    final empId = emp.employeeId.trim().replaceAll(RegExp('^0+'), '');
    if (empId == '16194') {
      try {
        avatarImg = await imageFromAssetBundle('assets/images/rakesh_tumane.jpg');
      } catch (_) {}
    } else if (empId == '17110') {
      try {
        avatarImg = await imageFromAssetBundle('assets/images/sameer_banerjee.jpg');
      } catch (_) {}
    } else if (empId == '540') {
      try {
        avatarImg = await imageFromAssetBundle('assets/images/swapnil_manpe.jpg');
      } catch (_) {}
    } else if (empId == '4410') {
      try {
        avatarImg = await imageFromAssetBundle('assets/images/ranjeet_chouhan.jpg');
      } catch (_) {}
    } else if (empId == '4428') {
      try {
        avatarImg = await imageFromAssetBundle('assets/images/bcn_gautam.jpg');
      } catch (_) {}
    }

    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            // Header Section
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
                    pw.Text(
                      'MOIL LIMITED',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xFF0F2080),
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Human Resource Information System',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '( EMPLOYEE PROFILE )',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(width: 50),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Divider(thickness: 1.5, color: PdfColors.black),
            pw.SizedBox(height: 8),

            // Employee Grid Block inside a Bordered Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(160),
                1: const pw.FlexColumnWidth(),
                2: const pw.FixedColumnWidth(160),
                3: const pw.FlexColumnWidth(),
              },
              children: [
                pw.TableRow(children: [
                  cellText('NAME', bold: true),
                  cellText(': ${emp.name}'),
                  cellText('EMP.NO / FORM B', bold: true),
                  cellText(': ${emp.employeeId.padLeft(8, '0')}'),
                ]),
                pw.TableRow(children: [
                  cellText('FATHER / SPOUSE NAME', bold: true),
                  cellText(': ${emp.fatherSpouseName}'),
                  cellText('BASIC (RS)', bold: true),
                  cellText(': ${emp.basicSalary}'),
                ]),
                pw.TableRow(children: [
                  cellText('DESIGNATION', bold: true),
                  cellText(': ${emp.designation}'),
                  cellText('PRESENT PLACE OF POSTING', bold: true),
                  cellText(': ${emp.presentPlaceOfPosting}'),
                ]),
                pw.TableRow(children: [
                  cellText('DEPARTMENT', bold: true),
                  cellText(': ${emp.department}'),
                  cellText('DATE OF PRESENT POSTING', bold: true),
                  cellText(': ${emp.dopp}'),
                ]),
                pw.TableRow(children: [
                  cellText('PRESENT GRADE', bold: true),
                  cellText(': ${emp.presentGrade}'),
                  cellText('DATE OF RETIREMENT', bold: true),
                  cellText(': ${emp.retirementDate}'),
                ]),
                pw.TableRow(children: [
                  cellText('DATE OF BIRTH', bold: true),
                  cellText(': ${emp.dateOfBirth}'),
                  cellText('MOBILE NO', bold: true),
                  cellText(': ${emp.mobileNumber}'),
                ]),
                pw.TableRow(children: [
                  cellText('DATE OF JOINING IN MOIL', bold: true),
                  cellText(': ${emp.joinDate}'),
                  cellText('E-MAIL', bold: true),
                  cellText(': ${emp.email}'),
                ]),
                pw.TableRow(children: [
                  cellText('DATE OF LAST PROMOTION', bold: true),
                  cellText(': ${emp.lastPromotionDate}'),
                  cellText('UAN NO', bold: true),
                  cellText(': ${emp.uanNo}'),
                ]),
                pw.TableRow(children: [
                  cellText('APPOINTMENT TYPE', bold: true),
                  cellText(': ${emp.appointmentType}'),
                  cellText('PAN NO', bold: true),
                  cellText(': ${emp.panNo}'),
                ]),
                pw.TableRow(children: [
                  cellText('CATEGORY', bold: true),
                  cellText(': ${emp.category}'),
                  cellText('AADHAR NO', bold: true),
                  cellText(': ${emp.aadhaarNo}'),
                ]),
                pw.TableRow(children: [
                  cellText('BLOOD GROUP', bold: true),
                  cellText(': ${emp.bloodGroup}'),
                  cellText('PRAN NO', bold: true),
                  cellText(': ${emp.pranNo}'),
                ]),
                pw.TableRow(children: [
                  cellText('GENDER', bold: true),
                  cellText(': ${emp.gender}'),
                  cellText('PF NO/SSPF NO', bold: true),
                  cellText(': ${emp.pfNo}'),
                ]),
                pw.TableRow(children: [
                  cellText('MARITAL STATUS', bold: true),
                  cellText(': ${emp.maritalStatus}'),
                  cellText('PENSION NO', bold: true),
                  cellText(': ${emp.pensionNo}'),
                ]),
              ],
            ),
            pw.SizedBox(height: 12),

            // Profile Photo Frame
            pw.Center(
              child: pw.Container(
                width: 90,
                height: 100,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey, width: 1),
                ),
                alignment: pw.Alignment.center,
                child: avatarImg != null
                    ? pw.Image(avatarImg, fit: pw.BoxFit.cover)
                    : pw.Text(
                        'Passport Size\nPhoto',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                      ),
              ),
            ),
            pw.SizedBox(height: 12),

            // Qualification Header
            pw.Center(
              child: pw.Container(
                width: double.infinity,
                color: PdfColors.grey200,
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'QUALIFICATION PROFILE',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ),
            pw.SizedBox(height: 4),

            // Qualification Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(50),
                1: const pw.FlexColumnWidth(),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    cellText('SL NO', bold: true, size: 8),
                    cellText('QUALIFICATION', bold: true, size: 8),
                  ],
                ),
                pw.TableRow(
                  children: [
                    cellText('1', size: 8),
                    cellText('B.COM., C.A.', size: 8),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // Family Header
            pw.Center(
              child: pw.Container(
                width: double.infinity,
                color: PdfColors.grey200,
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'FAMILY PARTICULARS',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ),
            pw.SizedBox(height: 4),

            // Family Particulars Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(40),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    cellText('SL NO', bold: true, size: 8),
                    cellText('NAME OF THE MEMBER', bold: true, size: 8),
                    cellText('RELATIONSHIP WITH THE EMPLOYEE', bold: true, size: 8),
                    cellText('DATE OF BIRTH', bold: true, size: 8),
                    cellText('GENDER', bold: true, size: 8),
                  ],
                ),
                if (emp.familyMembers.isNotEmpty)
                  ...emp.familyMembers.asMap().entries.map((e) {
                    final idx = e.key + 1;
                    final fam = e.value;
                    return pw.TableRow(children: [
                      cellText('$idx', size: 8),
                      cellText(fam['name'] ?? '', size: 8),
                      cellText(fam['relation'] ?? '', size: 8),
                      cellText(fam['dob'] ?? '', size: 8),
                      cellText(fam['gender'] ?? '', size: 8),
                    ]);
                  }).toList()
                else ...[
                  pw.TableRow(children: [
                    cellText('1', size: 8),
                    cellText(emp.fatherSpouseName, size: 8),
                    cellText('Spouse', size: 8),
                    cellText('N/A', size: 8),
                    cellText('Female', size: 8),
                  ]),
                ],
              ],
            ),
            pw.SizedBox(height: 12),

            // Nominees Header
            pw.Center(
              child: pw.Container(
                width: double.infinity,
                color: PdfColors.grey200,
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'NOMINEES OF EMPLOYEE',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ),
            pw.SizedBox(height: 4),

            // Nominees Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(40),
                1: const pw.FlexColumnWidth(2.5),
                2: const pw.FlexColumnWidth(2.5),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(1.5),
                5: const pw.FixedColumnWidth(45),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    cellText('SL.NO', bold: true, size: 8),
                    cellText('BENEFIT TYPE', bold: true, size: 8),
                    cellText('NOMINEE NAME', bold: true, size: 8),
                    cellText('RELATIONSHIP', bold: true, size: 8),
                    cellText('DATE OF BIRTH', bold: true, size: 8),
                    cellText('%AGE', bold: true, size: 8),
                  ],
                ),
                if (emp.nominees.isNotEmpty)
                  ...emp.nominees.asMap().entries.map((e) {
                    final idx = e.key + 1;
                    final nom = e.value;
                    return pw.TableRow(children: [
                      cellText('$idx', size: 8),
                      cellText(nom['benefit'] ?? '', size: 8),
                      cellText(nom['name'] ?? '', size: 8),
                      cellText(nom['relation'] ?? '', size: 8),
                      cellText(nom['dob'] ?? '', size: 8),
                      cellText('', size: 8),
                    ]);
                  }).toList()
                else ...[
                  pw.TableRow(children: [
                    cellText('1', size: 8),
                    cellText('Benevolent Fund Benefit', size: 8),
                    cellText('N/A', size: 8),
                    cellText('N/A', size: 8),
                    cellText('N/A', size: 8),
                    cellText('', size: 8),
                  ]),
                ],
              ],
            ),
            pw.SizedBox(height: 12),

            // Address Header
            pw.Center(
              child: pw.Container(
                width: double.infinity,
                color: PdfColors.grey200,
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'ADDRESS',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ),
            pw.SizedBox(height: 4),

            // Address Block
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey, width: 0.5),
              ),
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.RichText(
                    text: pw.TextSpan(
                      children: [
                        pw.TextSpan(text: 'PERMANENT ADDRESS: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                        pw.TextSpan(text: emp.address, style: pw.TextStyle(fontSize: 8.5)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.RichText(
                    text: pw.TextSpan(
                      children: [
                        pw.TextSpan(text: 'LOCAL ADDRESS: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                        pw.TextSpan(text: emp.address, style: pw.TextStyle(fontSize: 8.5)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.RichText(
                    text: pw.TextSpan(
                      children: [
                        pw.TextSpan(text: 'EMERGENCY ADDRESS: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                        pw.TextSpan(text: emp.address, style: pw.TextStyle(fontSize: 8.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Service Particulars Header
            pw.Center(
              child: pw.Container(
                width: double.infinity,
                color: PdfColors.grey200,
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'SERVICE PARTICULARS',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ),
            pw.SizedBox(height: 4),

            // Service Particulars Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(30),
                1: const pw.FlexColumnWidth(2.5),
                2: const pw.FixedColumnWidth(40),
                3: const pw.FlexColumnWidth(1.8),
                4: const pw.FlexColumnWidth(1.5),
                5: const pw.FlexColumnWidth(1.5),
                6: const pw.FlexColumnWidth(2.2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    cellText('SL NO', bold: true, size: 8),
                    cellText('DESIGNATION', bold: true, size: 8),
                    cellText('GRADE', bold: true, size: 8),
                    cellText('LOCATION', bold: true, size: 8),
                    cellText('FROM', bold: true, size: 8),
                    cellText('TO', bold: true, size: 8),
                    cellText('PAYSCALE', bold: true, size: 8),
                  ],
                ),
                if (emp.serviceHistory.isNotEmpty)
                  ...emp.serviceHistory.asMap().entries.map((e) {
                    final idx = e.key + 1;
                    final sh = e.value;
                    return pw.TableRow(children: [
                      cellText('$idx', size: 8),
                      cellText(sh['designation'] ?? '', size: 8),
                      cellText(sh['grade'] ?? '', size: 8),
                      cellText(sh['location'] ?? '', size: 8),
                      cellText(sh['from'] ?? '', size: 8),
                      cellText(sh['to'] ?? '', size: 8),
                      cellText(sh['payscale'] ?? '', size: 8),
                    ]);
                  }).toList()
                else ...[
                  pw.TableRow(children: [
                    cellText('1', size: 8),
                    cellText(emp.designation, size: 8),
                    cellText(emp.presentGrade, size: 8),
                    cellText(emp.presentPlaceOfPosting, size: 8),
                    cellText(emp.joinDate, size: 8),
                    cellText('Till Date', size: 8),
                    cellText(emp.basicSalary, size: 8),
                  ]),
                ],
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Employee_Profile_${emp.employeeId}.pdf',
    );
  }
}
