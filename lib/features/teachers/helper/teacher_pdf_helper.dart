import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:universal_html/html.dart' as html;
import 'package:http/http.dart' as http;
import 'package:alert_info/alert_info.dart';
import 'package:scholo_admin/models/teacher_model.dart';
import 'package:scholo_admin/models/school_model.dart';

class TeacherPdfHelper {
  static final primaryColor = PdfColor.fromHex("#1193D4");
  static final primaryDark = PdfColor.fromHex("#0E7490");
  static final textDark = PdfColor.fromHex("#0F172A");
  static final textMuted = PdfColor.fromHex("#64748B");
  static final borderColor = PdfColors.grey300;
  static final tableHeaderBg = PdfColor.fromHex("#1193D4");
  static final altRowBg = PdfColor.fromHex("#F8FAFC");

  /// Cleans any unsupported characters for PDF standard font rendering
  static String _cleanText(String? input) {
    if (input == null) return '';
    return input
        .replaceAll('₹', 'Rs. ')
        .replaceAll('•', '-')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('’', "'")
        .trim();
  }

  /// Generates the PDF binary bytes containing complete details of all given teachers
  static Future<Uint8List> generateTeachersListPdfBytes({
    required List<TeacherModel> teachers,
    SchoolModel? school,
  }) async {
    final pdf = pw.Document();

    final String schoolName = _cleanText(
      school?.schoolName.isNotEmpty == true
          ? school!.schoolName
          : "Duhss Thootha",
    );
    final String schoolCode = _cleanText(
      school?.schoolCode.isNotEmpty == true ? school!.schoolCode : "10098",
    );
    final String officialEmail = _cleanText(
      school?.officialEmail.isNotEmpty == true
          ? school!.officialEmail
          : "duhssthootha@gmail.com",
    );
    final String phoneNumber = _cleanText(
      school?.phoneNumber.isNotEmpty == true
          ? school!.phoneNumber
          : "+91 4933 285 240 / +91 9447 123 456",
    );
    final String schoolAddress = _cleanText(
      school?.schoolAddress.isNotEmpty == true
          ? school!.schoolAddress
          : "Thootha, Malappuram Dt., Kerala - 679357",
    );

    // Try fetching school logo image if available
    pw.MemoryImage? schoolLogoImage;
    if (school != null && school.imageUrl.isNotEmpty) {
      try {
        final response = await http
            .get(Uri.parse(school.imageUrl))
            .timeout(const Duration(seconds: 4));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          schoolLogoImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (_) {}
    }

    // Statistics calculation
    final totalTeachers = teachers.length;
    final maleCount = teachers.where((t) => t.gender.trim().toLowerCase() == 'male').length;
    final femaleCount = teachers.where((t) => t.gender.trim().toLowerCase() == 'female').length;
    final languageCount = teachers.where((t) => t.isLanguageTeacher).length;
    final generalCount = totalTeachers - languageCount;
    final classAssignedCount = teachers.where((t) => t.classNo != 0).length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        header: (context) {
          if (context.pageNumber == 1) {
            return _buildCoverHeader(
              schoolName: schoolName,
              schoolCode: schoolCode,
              email: officialEmail,
              phone: phoneNumber,
              address: schoolAddress,
              logo: schoolLogoImage,
              totalTeachers: totalTeachers,
            );
          } else {
            return _buildRunningHeader(
              schoolName: schoolName,
              pageNumber: context.pageNumber,
              pagesCount: context.pagesCount,
            );
          }
        },
        footer: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 8),
            padding: const pw.EdgeInsets.only(top: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "CONFIDENTIAL  Official Faculty & Teacher Directory  $schoolName",
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  "Generated on: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}",
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  "Page ${context.pageNumber} of ${context.pagesCount}",
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          );
        },
        build: (context) {
          return [
            // Stat badges summary
            _buildStatsCard(
              total: totalTeachers,
              male: maleCount,
              female: femaleCount,
              language: languageCount,
              general: generalCount,
              assigned: classAssignedCount,
            ),
            pw.SizedBox(height: 10),

            // All Teachers Complete Details Table
            _buildTeachersTable(teachers),

            pw.SizedBox(height: 18),

            // Authorization / Signatures block
            _buildSignaturesBlock(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Primary cover header for Page 1
  static pw.Widget _buildCoverHeader({
    required String schoolName,
    required String schoolCode,
    required String email,
    required String phone,
    required String address,
    required pw.MemoryImage? logo,
    required int totalTeachers,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: borderColor, width: 0.5),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // School Logo / Badge
          if (logo != null)
            pw.Container(
              width: 52,
              height: 52,
              margin: const pw.EdgeInsets.only(right: 12),
              child: pw.ClipRRect(
                horizontalRadius: 6,
                verticalRadius: 6,
                child: pw.Image(logo, fit: pw.BoxFit.cover),
              ),
            )
          else
            pw.Container(
              width: 52,
              height: 52,
              margin: const pw.EdgeInsets.only(right: 12),
              decoration: pw.BoxDecoration(
                color: primaryColor,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Center(
                child: pw.Text(
                  schoolName.isNotEmpty ? schoolName[0].toUpperCase() : 'S',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),

          // School & Document Details
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Text(
                      schoolName,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#E2E8F0'),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(
                        "CODE: $schoolCode",
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#475569'),
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  "$address | Phone: $phone | Email: $email",
                  style: pw.TextStyle(fontSize: 8.5, color: textMuted),
                ),
              ],
            ),
          ),

          // Document Badge
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#EFF6FF'),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: primaryColor, width: 0.8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  "TEACHERS DIRECTORY",
                  style: pw.TextStyle(
                    color: primaryColor,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  "Complete Faculty Record",
                  style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Running header for subsequent pages
  static pw.Widget _buildRunningHeader({
    required String schoolName,
    required int pageNumber,
    required int pagesCount,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            "$schoolName - Teachers Directory (Continued)",
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor),
          ),
          pw.Text(
            "Page $pageNumber of $pagesCount",
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  /// Compact statistics card row
  static pw.Widget _buildStatsCard({
    required int total,
    required int male,
    required int female,
    required int language,
    required int general,
    required int assigned,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex("#F1F5F9"),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: borderColor, width: 0.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildStatPill("Total Faculty", "$total", primaryColor),
          _buildStatPill("Male Teachers", "$male", PdfColor.fromHex("#2563EB")),
          _buildStatPill("Female Teachers", "$female", PdfColor.fromHex("#DB2777")),
          _buildStatPill("Language Teachers", "$language", PdfColor.fromHex("#7C3AED")),
          _buildStatPill("General Teachers", "$general", PdfColor.fromHex("#059669")),
          _buildStatPill("Class In-charge", "$assigned", PdfColor.fromHex("#D97706")),
        ],
      ),
    );
  }

  static pw.Widget _buildStatPill(String label, String value, PdfColor color) {
    return pw.Row(
      children: [
        pw.Text(
          "$label: ",
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: color),
        ),
      ],
    );
  }

  /// Complete Teachers Directory Table (12 comprehensive columns)
  static pw.Widget _buildTeachersTable(List<TeacherModel> teachers) {
    return pw.Table(
      border: pw.TableBorder.all(color: borderColor, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(24),  // #
        1: pw.FixedColumnWidth(44),  // Emp ID
        2: pw.FixedColumnWidth(92),  // Teacher Name
        3: pw.FixedColumnWidth(42),  // Gender
        4: pw.FixedColumnWidth(54),  // DOB
        5: pw.FixedColumnWidth(56),  // Class & Div
        6: pw.FixedColumnWidth(64),  // Subject
        7: pw.FixedColumnWidth(56),  // Role Type
        8: pw.FixedColumnWidth(74),  // Mobile No
        9: pw.FixedColumnWidth(116), // Email Address
        10: pw.FixedColumnWidth(66), // Password
        11: pw.FlexColumnWidth(1),   // Address
      },
      children: [
        // Table Header
        pw.TableRow(
          decoration: pw.BoxDecoration(color: tableHeaderBg),
          children: [
            _buildTh("#", alignCenter: true),
            _buildTh("Emp ID", alignCenter: true),
            _buildTh("Teacher Name"),
            _buildTh("Gender", alignCenter: true),
            _buildTh("DOB", alignCenter: true),
            _buildTh("Class & Div", alignCenter: true),
            _buildTh("Subject"),
            _buildTh("Role Type", alignCenter: true),
            _buildTh("Mobile"),
            _buildTh("Email"),
            _buildTh("Password"),
            _buildTh("Address"),
          ],
        ),

        // Table Data Rows
        ...List.generate(teachers.length, (index) {
          final t = teachers[index];
          final isEven = index % 2 == 0;
          final rowBg = isEven ? PdfColors.white : altRowBg;

          final dobStr =
              "${t.dateOfBirth.day.toString().padLeft(2, '0')}/${t.dateOfBirth.month.toString().padLeft(2, '0')}/${t.dateOfBirth.year}";
          final classStr = t.classNo == 0 ? "Not Assigned" : "${t.classNo} - ${t.division}";
          final roleStr = t.isLanguageTeacher ? "Language" : "General";

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: rowBg),
            children: [
              _buildTd("${index + 1}", alignCenter: true),
              _buildTd("#${_cleanText(t.employeeId)}", isBold: true, alignCenter: true),
              _buildTd(_cleanText(t.teacherName), isBold: true, color: PdfColor.fromHex("#0F172A")),
              _buildTd(_cleanText(t.gender), alignCenter: true),
              _buildTd(dobStr, alignCenter: true),
              _buildTd(classStr, alignCenter: true),
              _buildTd(_cleanText(t.subject).isNotEmpty ? _cleanText(t.subject) : "-"),
              _buildTd(roleStr, alignCenter: true),
              _buildTd(_cleanText(t.mobileNo).isNotEmpty ? _cleanText(t.mobileNo) : "-"),
              _buildTd(_cleanText(t.email).isNotEmpty ? _cleanText(t.email) : "-"),
              _buildTd(_cleanText(t.password).isNotEmpty ? _cleanText(t.password) : "-"),
              _buildTd(_cleanText(t.address).isNotEmpty ? _cleanText(t.address) : "-"),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildTh(String text, {bool alignCenter = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      alignment: alignCenter ? pw.Alignment.center : pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
          fontSize: 8,
        ),
      ),
    );
  }

  static pw.Widget _buildTd(
    String text, {
    bool isBold = false,
    bool alignCenter = false,
    PdfColor? color,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      alignment: alignCenter ? pw.Alignment.center : pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: color ?? PdfColor.fromHex("#334155"),
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 7.5,
        ),
      ),
    );
  }

  /// Official signature and seal verification block
  static pw.Widget _buildSignaturesBlock() {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: borderColor, width: 0.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _buildSignatureLine("Prepared by (Admin In-Charge)"),
          _buildSignatureLine("Verified by (Academic Coordinator)"),
          _buildSignatureLine("Principal / Head of Institution (Seal & Sign)"),
        ],
      ),
    );
  }

  static pw.Widget _buildSignatureLine(String designation) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: 180,
          margin: const pw.EdgeInsets.only(bottom: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.8, style: pw.BorderStyle.dashed)),
          ),
        ),
        pw.Text(
          designation,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ],
    );
  }

  /// One-tap download handler
  static Future<void> downloadTeachersListPdf({
    required List<TeacherModel> teachers,
    SchoolModel? school,
    required BuildContext context,
  }) async {
    try {
      final bytes = await generateTeachersListPdfBytes(
        teachers: teachers,
        school: school,
      );

      final String dateSlug = DateFormat('yyyyMMdd').format(DateTime.now());
      final String filename = "Teachers_Directory_$dateSlug.pdf";

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', filename)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        await Printing.sharePdf(bytes: bytes, filename: filename);
      }

      if (context.mounted) {
        AlertInfo.show(
          context: context,
          text: "Downloaded $filename successfully!",
          typeInfo: TypeInfo.success,
          backgroundColor: const Color(0xFF10B981),
          textColor: Colors.white,
        );
      }
    } catch (e) {
      if (context.mounted) {
        AlertInfo.show(
          context: context,
          text: "Error generating PDF: $e",
          typeInfo: TypeInfo.error,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  /// Preview / Print Handler
  static Future<void> printTeachersListPdf({
    required List<TeacherModel> teachers,
    SchoolModel? school,
    required BuildContext context,
  }) async {
    try {
      final bytes = await generateTeachersListPdfBytes(
        teachers: teachers,
        school: school,
      );
      final String dateSlug = DateFormat('yyyyMMdd').format(DateTime.now());
      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name: "Teachers_Directory_$dateSlug.pdf",
      );
    } catch (e) {
      if (context.mounted) {
        AlertInfo.show(
          context: context,
          text: "Error opening print preview: $e",
          typeInfo: TypeInfo.error,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }
}
