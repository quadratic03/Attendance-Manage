import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/learner.dart';
import '../models/section_schedule.dart';
import 'section_learners_page.dart';
import '../models/styling_classes.dart';
import 'student_attendance_page.dart';
import 'package:hive/hive.dart';
import 'section_details.dart';

class ReportsTab extends StatefulWidget {
  @override
  _ReportsTabState createState() => _ReportsTabState();

  // Add missing properties
  final Map<String, Map<String, String>> attendanceRecords;
  final List<SectionSchedule> sectionSchedules;
  final List<Learner> learners;
  final DateTime selectedDate;
  final bool isDarkMode;
  final Color textColor;
  final ItemStyling itemStyling;

  ReportsTab({
    required this.attendanceRecords,
    required this.sectionSchedules,
    required this.learners,
    required this.selectedDate,
    required this.isDarkMode,
    required this.textColor,
    required this.itemStyling,
  });
}

class _ReportsTabState extends State<ReportsTab> {
  String reportType = 'Weekly';
  DateTime selectedDate = DateTime.now();
  String selectedSection = 'All Sections';
  final GlobalKey downloadReportKey = GlobalKey();

  Map<AttendanceStatus, int> getAttendanceSummary(String startDate, String endDate, List<String> learnerIds) {
    Map<AttendanceStatus, int> summary = {
      AttendanceStatus.present: 0,
      AttendanceStatus.late: 0,
      AttendanceStatus.absent: 0,
    };

    for (var date in widget.attendanceRecords.keys) {
      if (date.compareTo(startDate) >= 0 && date.compareTo(endDate) <= 0) {
        var records = widget.attendanceRecords[date]!;
        for (var learnerId in learnerIds) {
          if (records.containsKey(learnerId)) {
            summary[AttendanceStatus.values.firstWhere((e) => e.toString() == records[learnerId]!['status'])] = summary[AttendanceStatus.values.firstWhere((e) => e.toString() == records[learnerId]!['status'])]! + 1;
          } else {
            summary[AttendanceStatus.absent] = summary[AttendanceStatus.absent]! + 1;
          }
        }
      }
    }
    return summary;
  }

  Map<String, Map<AttendanceStatus, int>> getStudentAttendanceSummary(String startDate, String endDate) {
    Map<String, Map<AttendanceStatus, int>> studentSummaries = {};

    for (var learner in widget.learners) {
      studentSummaries[learner.id] = {
        AttendanceStatus.present: 0,
        AttendanceStatus.late: 0,
        AttendanceStatus.absent: 0,
      };
    }

    for (var date in widget.attendanceRecords.keys) {
      if (date.compareTo(startDate) >= 0 && date.compareTo(endDate) <= 0) {
        var records = widget.attendanceRecords[date]!;
        for (var learner in widget.learners) {
          if (records.containsKey(learner.id)) {
            studentSummaries[learner.id]![AttendanceStatus.values.firstWhere((e) => e.toString() == records[learner.id]!['status'])] = studentSummaries[learner.id]![AttendanceStatus.values.firstWhere((e) => e.toString() == records[learner.id]!['status'])]! + 1;
          } else {
            studentSummaries[learner.id]![AttendanceStatus.absent] = studentSummaries[learner.id]![AttendanceStatus.absent]! + 1;
          }
        }
      }
    }
    return studentSummaries;
  }

  void _generateAndDownloadReport(BuildContext context) async {
    final pdf = pw.Document();

    String startDate, endDate, reportTitle;
    switch (reportType) {
      case 'Weekly':
        int dayOfWeek = selectedDate.weekday;
        DateTime startOfWeek = selectedDate.subtract(Duration(days: dayOfWeek - 1));
        DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));
        startDate = DateFormat('yyyy-MM-dd').format(startOfWeek);
        endDate = DateFormat('yyyy-MM-dd').format(endOfWeek);
        reportTitle = 'Weekly Attendance Report: $startDate to $endDate';
        break;
      case 'Monthly':
        DateTime firstDay = DateTime(selectedDate.year, selectedDate.month, 1);
        DateTime lastDay = DateTime(selectedDate.year, selectedDate.month + 1, 0);
        startDate = DateFormat('yyyy-MM-dd').format(firstDay);
        endDate = DateFormat('yyyy-MM-dd').format(lastDay);
        reportTitle = 'Monthly Attendance Report: ${DateFormat('MMMM yyyy').format(selectedDate)}';
        break;
      case 'Quarter 1':
        startDate = DateFormat('yyyy-MM-dd').format(DateTime(selectedDate.year, 1, 1));
        endDate = DateFormat('yyyy-MM-dd').format(DateTime(selectedDate.year, 3, 31));
        reportTitle = 'Quarter 1 Report: ${selectedDate.year} (Jan-Mar)';
        break;
      case 'Quarter 2':
        startDate = DateFormat('yyyy-MM-dd').format(DateTime(selectedDate.year, 4, 1));
        endDate = DateFormat('yyyy-MM-dd').format(DateTime(selectedDate.year, 6, 30));
        reportTitle = 'Quarter 2 Report: ${selectedDate.year} (Apr-Jun)';
        break;
      case 'Quarter 3':
        startDate = DateFormat('yyyy-MM-dd').format(DateTime(selectedDate.year, 7, 1));
        endDate = DateFormat('yyyy-MM-dd').format(DateTime(selectedDate.year, 9, 30));
        reportTitle = 'Quarter 3 Report: ${selectedDate.year} (Jul-Sep)';
        break;
      case 'Quarter 4':
        startDate = DateFormat('yyyy-MM-dd').format(DateTime(selectedDate.year, 10, 1));
        endDate = DateFormat('yyyy-MM-dd').format(DateTime(selectedDate.year, 12, 31));
        reportTitle = 'Quarter 4 Report: ${selectedDate.year} (Oct-Dec)';
        break;
      default:
        startDate = endDate = reportTitle = '';
    }

    List<Learner> filteredLearners = selectedSection == 'All Sections'
        ? widget.learners
        : widget.learners.where((l) => l.section == selectedSection).toList();
    Map<String, Map<AttendanceStatus, int>> studentSummaries = getStudentAttendanceSummary(startDate, endDate);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'Department of Education',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              reportTitle,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 15),
          ],
        ),
        build: (pw.Context pdfContext) {
          List<pw.Widget> content = [];
          int sectionIndex = 0;

          for (var schedule in widget.sectionSchedules) {
            if (selectedSection != 'All Sections' && schedule.section != selectedSection) {
              continue;
            }
            List<Learner> sectionLearners =
                filteredLearners.where((learner) => learner.section == schedule.section).toList();
            sectionLearners.sort((a, b) => a.name.compareTo(b.name));
            if (sectionLearners.isEmpty) continue;

            content.addAll([
              pw.Text(
                schedule.section,
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Table.fromTextArray(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: const pw.FixedColumnWidth(40),
                  1: const pw.FixedColumnWidth(120),
                  2: const pw.FixedColumnWidth(40),
                  3: const pw.FixedColumnWidth(40),
                  4: const pw.FixedColumnWidth(40),
                  5: const pw.FixedColumnWidth(40),
                  6: const pw.FixedColumnWidth(40),
                },
                headers: ['ID', 'Learner\'s Name', 'Present', 'Late', 'Absent', 'TP', 'TA'],
                data: sectionLearners.asMap().entries.map((entry) {
                  int index = entry.key + 1;
                  Learner learner = entry.value;
                  Map<AttendanceStatus, int> studentSummary = studentSummaries[learner.id]!;
                  return [
                    index.toString(),
                    learner.name,
                    studentSummary[AttendanceStatus.present].toString(),
                    studentSummary[AttendanceStatus.late].toString(),
                    studentSummary[AttendanceStatus.absent].toString(),
                    studentSummary[AttendanceStatus.present].toString(),
                    studentSummary[AttendanceStatus.absent].toString(),
                  ];
                }).toList(),
              ),
            ]);

            sectionIndex++;
            if (sectionIndex <
                widget.sectionSchedules
                    .where((s) => selectedSection == 'All Sections' || s.section == selectedSection)
                    .length) {
              content.add(pw.NewPage());
            }
          }

          return content;
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: '$reportTitle.pdf');
  }

  @override
  Widget build(BuildContext context) {
    String startDate, endDate, reportTitle;
    switch (reportType) {
      case 'Weekly':
        int dayOfWeek = selectedDate.weekday;
        DateTime startOfWeek = selectedDate.subtract(Duration(days: dayOfWeek - 1));
        DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));
        startDate = DateFormat('yyyy-MM-dd').format(startOfWeek);
        endDate = DateFormat('yyyy-MM-dd').format(endOfWeek);
        reportTitle = 'Weekly Attendance Report: $startDate to $endDate';
        break;
      case 'Monthly':
        DateTime firstDay = DateTime(selectedDate.year, selectedDate.month, 1);
        DateTime lastDay = DateTime(selectedDate.year, selectedDate.month + 1, 0);
        startDate = DateFormat('yyyy-MM-dd').format(firstDay);
        endDate = DateFormat('yyyy-MM-dd').format(lastDay);
        reportTitle = 'Monthly Attendance Report: ${DateFormat('MMMM yyyy').format(selectedDate)}';
        break;
      case 'Quarter 1':
        startDate = DateFormat('yyyy-MM-dd').format(DateTime(selectedDate.year, 1, 1));
        endDate = DateFormat('yyyy-MM-dd').format(DateTime(selectedDate.year, 3, 31));
        reportTitle = 'Quarter 1 Report: ${selectedDate.year} (Jan-Mar)';
        break;
      case 'Quarter 2':
        startDate = DateFormat('yyyy-MM-dd').format(DateTime(selectedDate.year, 4, 1));
        endDate = DateFormat('yyyy-MM-dd').format(DateTime(selectedDate.year, 6, 30));
        reportTitle = 'Quarter 2 Report: ${selectedDate.year} (Apr-Jun)';
        break;
      case 'Quarter 3':
        startDate = DateFormat('yyyy-MM-dd').format(DateTime(selectedDate.year, 7, 1));
        endDate = DateFormat('yyyy-MM-dd').format(DateTime(selectedDate.year, 9, 30));
        reportTitle = 'Quarter 3 Report: ${selectedDate.year} (Jul-Sep)';
        break;
      case 'Quarter 4':
        startDate = DateFormat('yyyy-MM-dd').format(DateTime(selectedDate.year, 10, 1));
        endDate = DateFormat('yyyy-MM-dd').format(DateTime(selectedDate.year, 12, 31));
        reportTitle = 'Quarter 4 Report: ${selectedDate.year} (Oct-Dec)';
        break;
      default:
        startDate = endDate = reportTitle = '';
    }

    List<Learner> filteredLearners = selectedSection == 'All Sections'
        ? widget.learners
        : widget.learners.where((l) => l.section == selectedSection).toList();
    List<String> learnerIds = filteredLearners.map((l) => l.id).toList();
    Map<AttendanceStatus, int> summary = getAttendanceSummary(startDate, endDate, learnerIds);
    double total = (summary[AttendanceStatus.present]?.toDouble() ?? 0.0) +
        (summary[AttendanceStatus.late]?.toDouble() ?? 0.0) +
        (summary[AttendanceStatus.absent]?.toDouble() ?? 0.0);

    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: 200,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF003087),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        ),
                        onPressed: () {},
                        child: PopupMenuButton<String>(
                          onSelected: (value) {
                            setState(() => selectedSection = value);
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'All Sections', child: Text('All Sections', style: TextStyle(fontSize: 14))),
                            ...widget.sectionSchedules.map((s) => PopupMenuItem(value: s.section, child: Text(s.section, style: const TextStyle(fontSize: 14)))),
                          ],
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Expanded(
                                child: Text(
                                  selectedSection,
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Icon(Icons.arrow_drop_down, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF003087),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        ),
                        onPressed: () {},
                        child: PopupMenuButton<String>(
                          onSelected: (value) {
                            setState(() => reportType = value);
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'Weekly', child: Text('Weekly', style: TextStyle(fontSize: 14))),
                            const PopupMenuItem(value: 'Monthly', child: Text('Monthly', style: TextStyle(fontSize: 14))),
                            const PopupMenuItem(value: 'Quarter 1', child: Text('Quarter 1', style: TextStyle(fontSize: 14))),
                            const PopupMenuItem(value: 'Quarter 2', child: Text('Quarter 2', style: TextStyle(fontSize: 14))),
                            const PopupMenuItem(value: 'Quarter 3', child: Text('Quarter 3', style: TextStyle(fontSize: 14))),
                            const PopupMenuItem(value: 'Quarter 4', child: Text('Quarter 4', style: TextStyle(fontSize: 14))),
                          ],
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Expanded(
                                child: Text(
                                  reportType,
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Icon(Icons.arrow_drop_down, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      key: downloadReportKey,
                      onPressed: () => _generateAndDownloadReport(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF003087),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                      ),
                      child: const Text('Download Report', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                TextButton(
                  onPressed: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => selectedDate = picked);
                  },
                  child: Text(
                    DateFormat('MMMM dd, yyyy').format(selectedDate),
                    style: const TextStyle(color: Color(0xFFFFC107), fontSize: 16),
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  reportTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: widget.textColor, // Use textColor
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                if (total > 0)
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.2,
                    child: PieChart(
                      PieChartData(
                        sections: [
                          PieChartSectionData(
                            value: (summary[AttendanceStatus.present]?.toDouble() ?? 0.0),
                            color: Colors.green,
                            title:
                                'P: ${((summary[AttendanceStatus.present]?.toDouble() ?? 0.0) / total * 100).toStringAsFixed(1)}%',
                            titleStyle: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          PieChartSectionData(
                            value: (summary[AttendanceStatus.late]?.toDouble() ?? 0.0),
                            color: Colors.yellow,
                            title:
                                'L: ${((summary[AttendanceStatus.late]?.toDouble() ?? 0.0) / total * 100).toStringAsFixed(1)}%',
                            titleStyle: const TextStyle(color: Colors.black, fontSize: 12),
                          ),
                          PieChartSectionData(
                            value: (summary[AttendanceStatus.absent]?.toDouble() ?? 0.0),
                            color: Colors.red,
                            title:
                                'A: ${((summary[AttendanceStatus.absent]?.toDouble() ?? 0.0) / total * 100).toStringAsFixed(1)}%',
                            titleStyle: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
                  )
                else
                  const Text('No attendance data available for this section',
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.sectionSchedules.length,
            itemBuilder: (context, index) {
              final section = widget.sectionSchedules[index];
              var sectionLearners = widget.learners
                  .where((learner) => learner.section == section.section)
                  .toList();
                  
              if (widget.isDarkMode) {
                sectionLearners = sectionLearners.reversed.toList();
              }

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: widget.itemStyling.sectionHeaderBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ExpansionTile(
                  title: Text(
                    section.section,
                    style: TextStyle(
                      color: widget.textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  children: sectionLearners.map((learner) {
                    final dateKey = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
                    final statusRecord = widget.attendanceRecords[dateKey]?[learner.id];
                    final status = AttendanceStatus.values.firstWhere((e) => e.toString() == statusRecord?['status'], orElse: () => AttendanceStatus.absent);
                    final statusColor = _getStatusColor(status, widget.isDarkMode);
                    final statusText = _getStatusText(status);

                    return Card(
                      color: widget.itemStyling.cardBackground,
                      elevation: 2,
                      child: ListTile(
                        tileColor: widget.itemStyling.cardBackground,
                        textColor: widget.textColor,
                        title: Text(learner.name),
                        subtitle: Text(learner.section),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: statusColor),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StudentAttendancePage(
                                learner: learner,
                                attendanceRecords: widget.attendanceRecords as Map<String, Map<String, Map<String, dynamic>>>,
                                selectedDate: widget.selectedDate,
                                isDarkMode: widget.isDarkMode,
                                textColor: widget.textColor,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<TextSpan> _buildDaySpans(SectionSchedule section, Color textColor) {
    final today = DateFormat('EEEE').format(DateTime.now()); // Get current day name
    final bool isDarkMode = widget.isDarkMode;
    
    List<TextSpan> spans = [
      TextSpan(
        text: section.classTime != null 
            ? 'Time: ${section.classTime!.format(context)}\n'
            : 'Time: Not set\n',
        style: TextStyle(
          color: textColor.withOpacity(0.7),
        ),
      ),
      TextSpan(
        text: 'Days: ',
        style: TextStyle(
          color: textColor.withOpacity(0.7),
        ),
      ),
    ];

    for (int i = 0; i < section.classDays.length; i++) {
      if (i > 0) {
        spans.add(TextSpan(
          text: ', ',
          style: TextStyle(
            color: textColor.withOpacity(0.7),
          ),
        ));
      }

      spans.add(
        TextSpan(
          text: section.classDays[i],
          style: TextStyle(
            color: section.classDays[i] == today 
                ? (isDarkMode ? Colors.yellow[300] : Colors.blue[700])
                : textColor.withOpacity(0.7),
            fontWeight: section.classDays[i] == today ? FontWeight.bold : FontWeight.normal,
            backgroundColor: section.classDays[i] == today 
                ? (isDarkMode ? Colors.blue[900]!.withOpacity(0.3) : Colors.yellow[100])
                : null,
          ),
        ),
      );
    }

    return spans;
  }

  Color _getStatusColor(AttendanceStatus status, bool isDarkMode) {
    switch (status) {
      case AttendanceStatus.present:
        return isDarkMode ? Colors.green[300]! : Colors.green[700]!;
      case AttendanceStatus.late:
        return isDarkMode ? Colors.orange[300]! : Colors.orange[700]!;
      case AttendanceStatus.absent:
        return isDarkMode ? Colors.red[300]! : Colors.red[700]!;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.late:
        return 'Late';
      case AttendanceStatus.absent:
        return 'Absent';
      default:
        return 'Unknown';
    }
  }
}