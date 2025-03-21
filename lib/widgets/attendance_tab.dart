import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import '../models/learner.dart';
import '../models/section_schedule.dart';
import 'section_attendance_page.dart';

class AttendanceTab extends StatefulWidget {
  final List<SectionSchedule> sectionSchedules;
  final List<Learner> learners;
  final Map<String, Map<String, Map<String, dynamic>>> attendanceRecords;
  final DateTime selectedDate;
  final Function(DateTime) onDateChanged;
  final Function(String, AttendanceStatus) onAttendanceChanged;
  final VoidCallback onSaveAttendance;
  final Color textColor;
  final bool isDarkMode;

  const AttendanceTab({
    super.key,
    required this.sectionSchedules,
    required this.learners,
    required this.attendanceRecords,
    required this.selectedDate,
    required this.onDateChanged,
    required this.onAttendanceChanged,
    required this.onSaveAttendance,
    required this.textColor,
    required this.isDarkMode,
  });

  @override
  _AttendanceTabState createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {
  late Box<Map> attendanceRecordsBox;

  @override
  void initState() {
    super.initState();
    attendanceRecordsBox = Hive.box<Map>('attendanceRecords');
  }

  Future<void> _saveAttendanceRecords() async {
    final records = widget.attendanceRecords.map(
      (date, records) => MapEntry(
        date,
        records.map(
          (id, record) => MapEntry(
            id,
            {
              'status': record['status'].toString(),
              'time': (record['time'] as DateTime).toIso8601String(),
            },
          ),
        ),
      ),
    );

    // Ensure the records are converted to a Map<String, Object>
    final Map<String, Object> formattedRecords = records.map(
      (key, value) => MapEntry(key, value as Object),
    );

    await attendanceRecordsBox.put('records', formattedRecords);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  List<TextSpan> _buildDaySpans(SectionSchedule section, Color textColor) {
    final today = DateFormat('EEEE').format(DateTime.now());
    final bool isDarkMode = widget.isDarkMode;
    
    List<TextSpan> spans = [
      TextSpan(
        text: section.classTime != null 
            ? 'Time: ${_formatTime(section.classTime!)}\n'
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

  void _handleAttendanceChanged(String learnerId, AttendanceStatus status) {
    setState(() {
      String dateKey = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
      if (widget.attendanceRecords[dateKey] == null) {
        widget.attendanceRecords[dateKey] = {};
      }
      widget.attendanceRecords[dateKey]![learnerId] = {
        'status': status,
        'time': DateTime.now(),
      };
    });
    widget.onAttendanceChanged(learnerId, status);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Attendance',
          style: TextStyle(color: widget.textColor),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.save, color: widget.textColor),
            onPressed: widget.onSaveAttendance,
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Selector
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: widget.textColor),
                  onPressed: () {
                    widget.onDateChanged(
                      widget.selectedDate.subtract(const Duration(days: 1)),
                    );
                  },
                ),
                TextButton(
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: widget.selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2101),
                    );
                    if (picked != null) {
                      widget.onDateChanged(picked);
                    }
                  },
                  child: Text(
                    DateFormat('MMMM d, y').format(widget.selectedDate),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: widget.textColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: widget.textColor),
                  onPressed: () {
                    widget.onDateChanged(
                      widget.selectedDate.add(const Duration(days: 1)),
                    );
                  },
                ),
              ],
            ),
          ),
          // Sections List
          Expanded(
            child: AnimatedList(
              initialItemCount: widget.sectionSchedules.length,
              itemBuilder: (context, index, animation) {
                final section = widget.sectionSchedules[index];
                var sectionLearners = widget.learners
                    .where((learner) => learner.section == section.section)
                    .toList();

                return SlideTransition(
                  position: animation as Animation<Offset>,
                  child: FadeTransition(
                    opacity: animation,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: widget.isDarkMode 
                              ? Colors.white24
                              : Colors.black12,
                          width: 1.0,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: widget.isDarkMode 
                            ? Colors.grey[900]
                            : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: widget.isDarkMode
                                ? Colors.black.withOpacity(0.3)
                                : Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ExpansionTile(
                          collapsedBackgroundColor: widget.isDarkMode 
                              ? const Color(0xFF383838)
                              : Colors.grey[50],
                          backgroundColor: widget.isDarkMode 
                              ? const Color(0xFF383838)
                              : Colors.grey[50],
                          title: Text(
                            section.section,
                            style: TextStyle(
                              color: widget.isDarkMode 
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: section.classTime != null
                              ? Text.rich(
                                  TextSpan(
                                    children: _buildDaySpans(section, widget.textColor),
                                    style: TextStyle(
                                      color: widget.isDarkMode
                                          ? Colors.white70
                                          : Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Schedule not set',
                                  style: TextStyle(
                                    color: widget.isDarkMode
                                        ? Colors.white38
                                        : Colors.black38,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                          children: [
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: sectionLearners.length,
                              itemBuilder: (context, index) {
                                final learner = sectionLearners[index];
                                String dateKey = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
                                Map<String, dynamic>? record = widget.attendanceRecords[dateKey]?[learner.id];
                                AttendanceStatus status = record?['status'] ?? AttendanceStatus.unchecked;

                                return Container(
                                  color: widget.isDarkMode 
                                      ? const Color(0xFF383838)
                                      : Colors.grey[50],
                                  child: ListTile(
                                    title: Text(
                                      learner.name,
                                      style: TextStyle(
                                        color: widget.isDarkMode
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.check_circle_outline,
                                            color: status == AttendanceStatus.present
                                                ? Colors.green
                                                : (widget.isDarkMode ? Colors.white38 : Colors.black38),
                                          ),
                                          onPressed: () => _handleAttendanceChanged(
                                            learner.id,
                                            AttendanceStatus.present,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.access_time,
                                            color: status == AttendanceStatus.late
                                                ? Colors.orange
                                                : (widget.isDarkMode ? Colors.white38 : Colors.black38),
                                          ),
                                          onPressed: () => _handleAttendanceChanged(
                                            learner.id,
                                            AttendanceStatus.late,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.cancel_outlined,
                                            color: status == AttendanceStatus.absent
                                                ? Colors.red
                                                : (widget.isDarkMode ? Colors.white38 : Colors.black38),
                                          ),
                                          onPressed: () => _handleAttendanceChanged(
                                            learner.id,
                                            AttendanceStatus.absent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                          onExpansionChanged: (expanded) {
                            if (expanded) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SectionAttendancePage(
                                    section: section,
                                    learners: widget.learners,
                                    attendanceRecords: widget.attendanceRecords,
                                    selectedDate: widget.selectedDate,
                                    onAttendanceChanged: widget.onAttendanceChanged,
                                    onSaveAttendance: widget.onSaveAttendance,
                                    attendanceRecordsBox: attendanceRecordsBox,
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderButton(
    BuildContext context,
    SectionSchedule section,
    Duration reminderTime,
    String label,
  ) {
    return ElevatedButton.icon(
      icon: const Icon(
        Icons.alarm,
        size: 16,
      ),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        textStyle: const TextStyle(fontSize: 12),
      ),
      onPressed: () async {
        // Calculate when the reminder will trigger
        final now = DateTime.now();
        final classTime = TimeOfDay(
          hour: section.classTime!.hour,
          minute: section.classTime!.minute,
        );
        
        // Convert class time to DateTime
        var reminderDateTime = DateTime(
          now.year,
          now.month,
          now.day,
          classTime.hour,
          classTime.minute,
        ).subtract(reminderTime);

        // If the time has already passed today, show tomorrow's time
        if (reminderDateTime.isBefore(now)) {
          reminderDateTime = reminderDateTime.add(const Duration(days: 1));
        }

        // Format the reminder time for display
        final reminderTimeString = DateFormat('h:mm a').format(reminderDateTime);
        
        // Show confirmation dialog
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.alarm, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text('Set Class Reminder'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Set reminder for ${section.section}:'),
                const SizedBox(height: 8),
                Text(
                  '• Class time: ${_formatTime(section.classTime!)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '• Reminder: $label',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '• Days: ${section.classDays.join(", ")}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                Text(
                  'First reminder will trigger at $reminderTimeString',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.alarm_on, size: 18),
                label: const Text('Set Reminder'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        );

        if (confirmed == true && context.mounted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.alarm_on, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reminder set for ${section.section}\nWill remind you $label',
                      ),
                    ),
                  ],
                ),
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: 'UNDO',
                  onPressed: () {},
                ),
              ),
            );
          }
        }
      },
    );
  }
}