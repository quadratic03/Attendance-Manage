import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add this import
import 'dart:convert'; // Add this import
import '../models/learner.dart';
import '../models/section_schedule.dart';

class SectionLearnersPage extends StatefulWidget {
  final SectionSchedule section;
  final List<Learner> learners;
  final List<SectionSchedule> sectionSchedules;
  final Map<String, Map<String, Map<String, dynamic>>> attendanceRecords;
  final DateTime selectedDate;
  final Function(String) onRemoveLearner;
  final Function(String, String, String, bool) onEditLearner;
  final bool isEditable; // Add this line

  const SectionLearnersPage({
    super.key,
    required this.section,
    required this.learners,
    required this.sectionSchedules,
    required this.attendanceRecords,
    required this.selectedDate,
    required this.onRemoveLearner,
    required this.onEditLearner,
    this.isEditable = true, // Add this line
  });

  @override
  _SectionLearnersPageState createState() => _SectionLearnersPageState();
}

class _SectionLearnersPageState extends State<SectionLearnersPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Learner> filteredLearners = [];
  List<Learner> deletedLearners = []; // Add this list

  @override
  void initState() {
    super.initState();
    filteredLearners = widget.learners.where((l) => l.section == widget.section.section).toList();
    _searchController.addListener(_filterLearners);
    _loadDeletedLearners(); // Load deleted learners from storage
  }

  Future<void> _loadDeletedLearners() async {
    final prefs = await SharedPreferences.getInstance();
    final deletedLearnersData = prefs.getStringList('deletedLearners') ?? [];
    setState(() {
      deletedLearners = deletedLearnersData.map((data) => Learner.fromJson(jsonDecode(data))).toList().cast<Learner>();
    });
  }

  Future<void> _saveDeletedLearners() async {
    final prefs = await SharedPreferences.getInstance();
    final deletedLearnersData = deletedLearners.map((learner) => jsonEncode(learner.toJson())).toList();
    await prefs.setStringList('deletedLearners', deletedLearnersData);
  }

  void _filterLearners() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredLearners = widget.learners.where((learner) {
        return (learner.name.toLowerCase().contains(query) || learner.id.toLowerCase().contains(query)) &&
            learner.section == widget.section.section;
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showOptionsDialog(BuildContext context, Learner learner) {
    if (!widget.isEditable) return; // Add this line

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(learner.name, style: const TextStyle(fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF003087), size: 20),
              title: const Text('Edit', style: TextStyle(fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                _showEditLearnerDialog(context, learner);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red, size: 20),
              title: const Text('Delete', style: TextStyle(fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm Delete', style: TextStyle(fontSize: 18)),
                    content: Text('Delete ${learner.name}?', style: const TextStyle(fontSize: 14)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel', style: TextStyle(fontSize: 14)),
                      ),
                      TextButton(
                        onPressed: () {
                          widget.onRemoveLearner(learner.id);
                          setState(() {
                            filteredLearners.removeWhere((l) => l.id == learner.id);
                            deletedLearners.add(learner); // Add learner to deleted list
                            _saveDeletedLearners(); // Save changes to storage
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Delete', style: TextStyle(fontSize: 14)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  void _showEditLearnerDialog(BuildContext context, Learner learner) {
    String name = learner.name;
    String section = learner.section;
    bool isPriority = learner.isPriority;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Learner', style: TextStyle(fontSize: 18)),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.75,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButton<String>(
                      isExpanded: true,
                      value: widget.sectionSchedules.any((s) => s.section == section)
                          ? section
                          : widget.sectionSchedules[0].section,
                      items: widget.sectionSchedules
                          .map((s) => DropdownMenuItem(value: s.section, child: Text(s.section, style: const TextStyle(fontSize: 14))))
                          .toList(),
                      onChanged: (value) => setDialogState(() => section = value!),
                    ),
                    TextField(
                      controller: TextEditingController(text: name),
                      decoration: const InputDecoration(labelText: 'Learner\'s Name', contentPadding: EdgeInsets.all(10)),
                      style: const TextStyle(fontSize: 14),
                      onChanged: (value) => name = value,
                    ),
                    CheckboxListTile(
                      title: const Text('Priority Learner', style: TextStyle(fontSize: 14)),
                      value: isPriority,
                      onChanged: (value) => setDialogState(() => isPriority = value ?? false),
                      dense: true,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(fontSize: 14)),
                ),
                TextButton(
                  onPressed: () {
                    if (name.isNotEmpty && section.isNotEmpty) {
                      widget.onEditLearner(learner.id, name, section, isPriority);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Save', style: TextStyle(fontSize: 14)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return Colors.green;
      case AttendanceStatus.late:
        return Colors.yellow;
      case AttendanceStatus.absent:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Learner> sectionLearners =
        widget.learners.where((learner) => learner.section == widget.section.section).toList();
    sectionLearners.sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.section.section} - Learners'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredLearners.length,
              itemBuilder: (context, index) {
                final learner = filteredLearners[index];
                String dateKey = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
                Map<String, dynamic>? record = widget.attendanceRecords[dateKey]?[learner.id];
                AttendanceStatus status = record?['status'] ?? AttendanceStatus.unchecked;

                return ListTile(
                  title: Text(learner.name),
                  subtitle: learner.isPriority
                      ? const Text(
                          'Priority',
                          style: TextStyle(
                            color: Color(0xFFFFC107),
                            fontSize: 12,
                          ),
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        status == AttendanceStatus.present
                            ? 'Present'
                            : status == AttendanceStatus.late
                                ? 'Late'
                                : status == AttendanceStatus.absent
                                    ? 'Absent'
                                    : 'Unchecked',
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontSize: 12,
                        ),
                      ),
                      if (widget.isEditable) // Add this line
                        IconButton(
                          icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                          onPressed: () => _showOptionsDialog(context, learner),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}