import 'package:flutter/material.dart';
import '../models/learner.dart';
import '../models/section_schedule.dart';
import 'package:intl/intl.dart';

class StudentAttendancePage extends StatelessWidget {
  final Learner learner;
  final Map<String, Map<String, Map<String, dynamic>>> attendanceRecords;
  final DateTime selectedDate;
  final bool isDarkMode;
  final Color textColor;

  const StudentAttendancePage({
    super.key,
    required this.learner,
    required this.attendanceRecords,
    required this.selectedDate,
    required this.isDarkMode,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final filteredRecords = attendanceRecords[dateFormat.format(selectedDate)] ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text(learner.name),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Attendance Status for ${dateFormat.format(selectedDate)}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 20),
                ...filteredRecords[learner.id]?.entries.map((entry) => ListTile(
                      title: Text('Status: ${_statusText(entry.value['status'])}'),
                      subtitle: Text('Time: ${DateFormat.jm().format(entry.value['time'] as DateTime)}'),
                      tileColor: _statusColor(entry.value['status'], isDarkMode),
                      textColor: textColor,
                    )) ?? [
                  ListTile(
                    title: Text('No attendance recorded', style: TextStyle(color: textColor)),
                    subtitle: Text('Student was not marked present', style: TextStyle(color: textColor)),
                  )
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusText(dynamic status) {
    if (status == AttendanceStatus.present) return 'Present';
    if (status == AttendanceStatus.late) return 'Late';
    return 'Absent';
  }

  Color _statusColor(dynamic status, bool isDarkMode) {
    switch (status) {
      case AttendanceStatus.present:
        return isDarkMode ? Colors.green[900]! : Colors.green[100]!;
      case AttendanceStatus.late:
        return isDarkMode ? Colors.orange[900]! : Colors.yellow[100]!;
      default:
        return isDarkMode ? Colors.red[900]! : Colors.red[100]!;
    }
  }
} 