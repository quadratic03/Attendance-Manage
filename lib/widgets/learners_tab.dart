import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/learner.dart';
import '../models/section_schedule.dart';
import 'section_learners_page.dart';
import 'package:intl/intl.dart';

class LearnersTab extends StatelessWidget {
  final List<Learner> learners;
  final List<SectionSchedule> sectionSchedules;
  final Map<String, Map<String, Map<String, dynamic>>> attendanceRecords;
  final DateTime selectedDate;
  final Function(String, String, bool) onAddLearner;
  final Function(String) onRemoveLearner;
  final Function(String, String, String, bool) onEditLearner;
  final Color textColor; // Add this line
  final bool isDarkMode; // Add this line

  const LearnersTab({
    super.key,
    required this.learners,
    required this.sectionSchedules,
    required this.attendanceRecords,
    required this.selectedDate,
    required this.onAddLearner,
    required this.onRemoveLearner,
    required this.onEditLearner,
    required this.textColor, // Add this line
    required this.isDarkMode, // Add this line
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      child: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Opacity(
                opacity: sectionSchedules.isEmpty ? 0.5 : 1.0,
                child: ElevatedButton(
                  onPressed: sectionSchedules.isEmpty
                      ? null
                      : () => _showAddLearnerDialog(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003087),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: const Text('Add Learner', style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sectionSchedules.length,
              itemBuilder: (context, index) {
                final section = sectionSchedules[index];
                var sectionLearners = learners.where((learner) => learner.section == section.section).toList();
                if (isDarkMode) {
                  sectionLearners = sectionLearners.reversed.toList(); // Invert the list if dark mode is enabled
                }
                return ExpansionTile(
                  title: Text(section.section, style: TextStyle(color: textColor)),
                  subtitle: section.classTime != null
                      ? Text.rich(
                          TextSpan(
                            children: _buildDaySpans(section, textColor),
                            style: TextStyle(
                              color: textColor.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        )
                      : Text(
                          'Schedule not set',
                          style: TextStyle(
                            color: textColor.withOpacity(0.7),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                  children: sectionLearners.map((learner) {
                    return ListTile(
                      title: Text(learner.name, style: TextStyle(color: textColor)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showEditLearnerDialog(learner),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => onRemoveLearner(learner.id),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onExpansionChanged: (expanded) {
                    if (expanded) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SectionLearnersPage(
                            section: section,
                            learners: learners,
                            sectionSchedules: sectionSchedules,
                            attendanceRecords: attendanceRecords,
                            selectedDate: selectedDate,
                            onRemoveLearner: onRemoveLearner,
                            onEditLearner: onEditLearner,
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveLearners() async {
    final learnersBox = Hive.box<Learner>('learners');
    await learnersBox.clear();
    for (var learner in learners) {
      await learnersBox.put(learner.id, learner);
    }
  }

  Future<void> _saveAttendanceRecords() async {
    final attendanceRecordsBox = Hive.box<Map>('attendanceRecords');
    final Map<String, Map<String, Map<String, Object>>> formattedRecords = {};
    
    attendanceRecords.forEach((date, records) {
      formattedRecords[date] = {};
      records.forEach((id, record) {
        formattedRecords[date]![id] = {
          'status': record['status'].toString(),
          'time': (record['time'] as DateTime).toIso8601String(),
        };
      });
    });

    await attendanceRecordsBox.put('records', formattedRecords);
  }

  void _showAddLearnerDialog(BuildContext context) {
    if (sectionSchedules.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Sections Available', style: TextStyle(fontSize: 18)),
          content: const Text('Add a section first before adding a student.', style: TextStyle(fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      );
      return;
    }

    String name = '';
    String section = sectionSchedules[0].section;
    bool isPriority = false;
    final TextEditingController nameController = TextEditingController();
    String? errorText;
            child: Opacity(
              opacity: widget.sectionSchedules.isEmpty ? 0.5 : 1.0,
              child: ElevatedButton(
                key: addLearnerKey,
                onPressed: widget.sectionSchedules.isEmpty
                    ? null
                    : () => _showAddLearnerDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003087),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('Add Learner', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.sectionSchedules.length,
            itemBuilder: (context, index) {
              final section = widget.sectionSchedules[index];
              var sectionLearners = widget.learners.where((learner) => learner.section == section.section).toList();
              if (widget.isDarkMode) {
                sectionLearners = sectionLearners.reversed.toList(); // Invert the list if dark mode is enabled
              }
              return ExpansionTile(
                title: Text(section.section, style: TextStyle(color: widget.textColor)),
                subtitle: section.classTime != null
                    ? Text.rich(
                        TextSpan(
                          children: _buildDaySpans(section, widget.textColor),
                          style: TextStyle(
                            color: widget.textColor.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      )
                    : Text(
                        'Schedule not set',
                        style: TextStyle(
                          color: widget.textColor.withOpacity(0.7),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                children: sectionLearners.map((learner) {
                  return ListTile(
                    title: Text(learner.name, style: TextStyle(color: widget.textColor)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showEditLearnerDialog(learner),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => widget.onRemoveLearner(learner.id),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onExpansionChanged: (expanded) {
                  if (expanded) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SectionLearnersPage(
                          section: section,
                          learners: widget.learners,
                          sectionSchedules: widget.sectionSchedules,
                          attendanceRecords: widget.attendanceRecords,
                          selectedDate: widget.selectedDate,
                          onRemoveLearner: widget.onRemoveLearner,
                          onEditLearner: widget.onEditLearner,
                        ),
                      ),
                    );
                  }
                },
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

  Widget _buildWarningItem(String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.remove_circle_outline,
            color: Colors.red[300],
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: textColor.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}