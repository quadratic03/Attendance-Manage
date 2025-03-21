import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:timezone/timezone.dart' as tz;
import '../models/learner.dart';
import '../models/section_schedule.dart';
import 'attendance_tab.dart';
import 'learners_tab.dart';
import 'reports_tab.dart';
import '../timezone_setup.dart';
import '../models/styling_classes.dart';

class AttendanceManager extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDarkMode;
  final Map<String, Map<String, Map<String, dynamic>>> attendanceRecords;
  final List<SectionSchedule> sectionSchedules;
  final List<Learner> learners;
  final ItemStyling itemStyling;
  final int tutorialStep;

  const AttendanceManager({
    super.key,
    required this.onThemeToggle,
    required this.isDarkMode,
    required this.attendanceRecords,
    required this.sectionSchedules,
    required this.learners,
    required this.itemStyling,
    this.tutorialStep = 0,
  });

  @override
  _AttendanceManagerState createState() => _AttendanceManagerState();
}

class _AttendanceManagerState extends State<AttendanceManager> with SingleTickerProviderStateMixin {
  late Box<Learner> learnersBox;
  late Box<SectionSchedule> sectionSchedulesBox;
  late Box<Map> attendanceRecordsBox;
  late Box<bool> settingsBox;
  List<Learner> learners = [];
  Map<String, Map<String, Map<String, dynamic>>> attendanceRecords = {};
  DateTime selectedDate = DateTime.now();
  int nextId = 1;
  List<SectionSchedule> sectionSchedules = [];
  List<Learner> deletedLearners = [];
  SectionSchedule? recentlyDeletedSection;
  List<Learner> recentlyDeletedLearners = [];

  final Map<String, List<String>> classDayOptions = {
    'Monday-Friday': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
    'Monday/Wednesday/Friday': ['Monday', 'Wednesday', 'Friday'],
    'Tuesday/Thursday': ['Tuesday', 'Thursday'],
    'Saturday-Sunday': ['Saturday', 'Sunday'],
  };

  Timer? _timer;
  final int classDurationMinutes = 60;
  Set<String> alertedSections = {};
  Set<String> alertedStartSections = {};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    initializeTimeZone();
    _tabController = TabController(length: 3, vsync: this);
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _initializeHive();
    _startTimeChecker();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabController.dispose();
    learnersBox.close();
    sectionSchedulesBox.close();
    attendanceRecordsBox.close();
    settingsBox.close();
    super.dispose();
  }

  Future<void> _initializeHive() async {
    learnersBox = Hive.box<Learner>('learners');
    sectionSchedulesBox = Hive.box<SectionSchedule>('sectionSchedules');
    attendanceRecordsBox = Hive.box<Map>('attendanceRecords');
    settingsBox = Hive.box<bool>('settings');

    // Load saved attendance records
    final savedRecords = attendanceRecordsBox.get('records');
    if (savedRecords != null) {
      attendanceRecords = Map<String, Map<String, Map<String, dynamic>>>.from(
        savedRecords.map(
              (key, value) => MapEntry(
                key,
                (value as Map).map(
                  (id, record) => MapEntry(
                id.toString(),
                    {
                  'status': AttendanceStatus.values.firstWhere(
                    (e) => e.toString() == record['status'],
                    orElse: () => AttendanceStatus.unchecked,
                  ),
                      'time': DateTime.parse(record['time']),
                    },
                  ),
                ),
              ),
        ),
      );

      // Clear old attendance records (older than today)
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      attendanceRecords.removeWhere((date, _) => date.compareTo(today) < 0);
      _saveAttendanceRecords();
    }

    setState(() {
      learners = learnersBox.values.toList();
      sectionSchedules = sectionSchedulesBox.values.toList();

      nextId = learners.isNotEmpty
          ? (learners.map((l) => int.parse(l.id)).reduce((a, b) => a > b ? a : b)) + 1
          : 1;

      if (sectionSchedules.isEmpty) {
        sectionSchedules = [];
        _saveSectionSchedules();
      }
    });
  }

  Future<void> _saveLearners() async {
    await learnersBox.clear();
    for (var learner in learners) {
      await learnersBox.put(learner.id, learner);
    }
  }

  Future<void> _saveAttendanceRecords() async {
    final records = attendanceRecords.map(
      (date, records) => MapEntry(
        date,
        Map<String, Object>.from(
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
      ),
    );
    
    await attendanceRecordsBox.put('records', records);
  }

  Future<void> _saveData() async {
    await _saveLearners();
    await _saveSectionSchedules();
    await _saveAttendanceRecords();
  }

  Future<void> _saveSectionSchedules() async {
    await sectionSchedulesBox.clear();
    for (var schedule in sectionSchedules) {
      await sectionSchedulesBox.put(schedule.section, schedule);
    }
  }

  void _startTimeChecker() {
    _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
      final now = DateTime.now();
      final currentDay = DateFormat('EEEE').format(now);

      for (var schedule in sectionSchedules) {
        if (schedule.classTime != null && schedule.classDays.contains(currentDay)) {
          final startTime = DateTime(
            now.year,
            now.month,
            now.day,
            schedule.classTime!.hour,
            schedule.classTime!.minute,
          );
          final endTime = startTime.add(Duration(minutes: classDurationMinutes));

          if (now.isAfter(startTime.subtract(const Duration(minutes: 1))) &&
              now.isBefore(startTime.add(const Duration(minutes: 1))) &&
              !alertedStartSections.contains(schedule.section)) {
            _showClassStartAlert(schedule.section);
            alertedStartSections.add(schedule.section);
          }

          if (now.isAfter(endTime) &&
              now.isBefore(endTime.add(const Duration(minutes: 1))) &&
              !alertedSections.contains(schedule.section)) {
            _showClassEndAlert(schedule.section);
            alertedSections.add(schedule.section);
          }
        }
      }

      if (now.hour == 0 && now.minute == 0) {
        alertedSections.clear();
        alertedStartSections.clear();
      }
    });
  }

  void _showClassStartAlert(String section) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Class Starting Now!'),
        content: Text('The class for $section is starting now.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showClassEndAlert(String section) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Class Ended'),
        content: Text('The class for $section has ended.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _markAttendance(String learnerId, AttendanceStatus status) {
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    
    setState(() {
      if (!attendanceRecords.containsKey(dateKey)) {
        attendanceRecords[dateKey] = {};
      }
      
      attendanceRecords[dateKey]![learnerId] = {
        'status': status,
        'time': DateTime.now(),
      };
      
      _saveAttendanceRecords();
    });
  }

  void _showAboutAppDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About App'),
        content: const Text(
          'Student Attendance Manager is a Flutter-based application designed to help teachers and administrators efficiently track student attendance. '
          'Features include marking attendance, managing learners, generating reports, and setting class schedules.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAppVersionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('App Version'),
        content: const Text('1.0.0'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showDevelopersDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Developers'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundImage: AssetImage('../assets/namoc.png'),
                      onBackgroundImageError: (_, __) {
                        print('Error loading namoc.png');
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundImage: AssetImage('../assets/mulit.png'),
                      onBackgroundImageError: (_, __) {
                        print('Error loading mulit.png');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Building the future of education, one app at a time.',
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Developed by:\n'
                '- NAMOC ROBERTH\n'
                '- JELLIANNE MULIT\n'
                'Contact: Kristinedais10@gmail.com',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDarkMode ? Colors.white : Colors.black;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: null, // Remove the default menu button
          centerTitle: true,
          title: const Text('Attendance Manager', style: TextStyle(fontSize: 18)),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: widget.isDarkMode ? Colors.white : const Color(0xFFFFC107),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(fontSize: 14),
            tabs: [
              const Tab(text: 'Attendance'),
              const Tab(text: 'Learners'),
              const Tab(text: 'Reports'),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode, size: 24),
              onPressed: widget.onThemeToggle,
            ),
          ],
        ),
        // Conditionally enable/disable the drawer based on dark mode
        drawer: widget.isDarkMode
            ? null // No drawer in dark mode
            : Drawer(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    DrawerHeader(
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                      ),
                      child: const Text(
                        'Menu',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: Icon(Icons.info, color: Theme.of(context).iconTheme.color),
                      title: Text('App Version', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                      onTap: () {
                        Navigator.pop(context);
                        _showAppVersionDialog();
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.language, color: Theme.of(context).iconTheme.color),
                      title: Text('Language Used', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                      onTap: () {
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Language Used'),
                            content: const Text('Dart'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.developer_mode, color: Theme.of(context).iconTheme.color),
                      title: Text('Developers', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                      onTap: () {
                        Navigator.pop(context);
                        _showDevelopersDialog();
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.info_outline, color: Theme.of(context).iconTheme.color),
                      title: Text('About App', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                      onTap: () {
                        Navigator.pop(context);
                        _showAboutAppDialog();
                      },
                    ),
                  ],
                ),
              ),
        body: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: [
              AttendanceTab(
                sectionSchedules: sectionSchedules,
                learners: learners,
                attendanceRecords: attendanceRecords,
                selectedDate: selectedDate,
                onDateChanged: (date) => setState(() {
                  selectedDate = date;
                  _saveAttendanceRecords();
                }),
                onAttendanceChanged: _markAttendance,
                onSaveAttendance: () {
                  setState(() {
                    _saveAttendanceRecords();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Attendance saved successfully')),
                  );
                },
                textColor: textColor, // Pass text color to AttendanceTab
                isDarkMode: widget.isDarkMode, // Pass isDarkMode to AttendanceTab
              ),
              LearnersTab(
                learners: learners,
                sectionSchedules: sectionSchedules,
                attendanceRecords: attendanceRecords,
                selectedDate: selectedDate,
                onAddLearner: (name, section, isPriority) {
                  setState(() {
                    String newId = nextId.toString();
                    learners.add(Learner(
                      id: newId,
                      name: name,
                      section: section,
                      isPriority: isPriority,
                    ));
                    nextId++;
                    _saveLearners();
                  });
                },
                onRemoveLearner: (learnerId) {
                  setState(() {
                    learners.removeWhere((learner) => learner.id == learnerId);
                    attendanceRecords.forEach((date, records) => records.remove(learnerId));
                    _saveLearners();
                    _saveAttendanceRecords();
                  });
                },
                onEditLearner: (learnerId, newName, newSection, newIsPriority) {
                  setState(() {
                    var learner = learners.firstWhere((l) => l.id == learnerId);
                    learner.name = newName;
                    learner.section = newSection;
                    learner.isPriority = newIsPriority;
                    _saveLearners();
                  });
                },
                isDarkMode: widget.isDarkMode,
                textColor: textColor,
                itemStyling: LearnersItemStyling(
                  backgroundColor: widget.isDarkMode ? Colors.grey[900]! : Colors.white,
                  sectionHeaderBackground: widget.isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
                  listItemBorder: widget.isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
                  cardBackground: widget.isDarkMode ? Colors.grey[850]! : Colors.white,
                ),
              ),
              ReportsTab(
                learners: learners,
                attendanceRecords: attendanceRecords,
                selectedDate: selectedDate,
                sectionSchedules: sectionSchedules,
                isDarkMode: widget.isDarkMode,
                textColor: textColor,
                itemStyling: ReportsItemStyling(
                  sectionHeaderBackground: widget.isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
                  cardBackground: widget.isDarkMode ? Colors.grey[900]! : Colors.white,
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showScheduleDialog(),
          child: const Icon(Icons.add, size: 24),
        ),
      ),
    );
  }

  void _showScheduleDialog() {
    final TextEditingController gradeController = TextEditingController();
    final TextEditingController sectionController = TextEditingController();

    bool isDuplicateSection(String newSection) {
      // Normalize the section name by trimming whitespace and converting to lowercase
      String normalizedNewSection = newSection.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      
      return sectionSchedules.any((schedule) {
        String normalizedExistingSection = schedule.section.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
        return normalizedExistingSection == normalizedNewSection;
      });
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Manage Sections', style: TextStyle(fontSize: 18)),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.85,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Add new section form
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: gradeController,
                              decoration: const InputDecoration(
                                labelText: 'Grade',
                                hintText: 'e.g., Grade 7',
                                contentPadding: EdgeInsets.all(10),
                              ),
                              style: const TextStyle(fontSize: 14),
                              onChanged: (value) {
                                // Trim whitespace as user types
                                if (value.trim() != value) {
                                  gradeController.text = value.trim();
                                  gradeController.selection = TextSelection.fromPosition(
                                    TextPosition(offset: gradeController.text.length),
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: sectionController,
                              decoration: const InputDecoration(
                                labelText: 'Section',
                                hintText: 'e.g., Section A',
                                contentPadding: EdgeInsets.all(10),
                              ),
                              style: const TextStyle(fontSize: 14),
                              onChanged: (value) {
                                // Trim whitespace as user types
                                if (value.trim() != value) {
                                  sectionController.text = value.trim();
                                  sectionController.selection = TextSelection.fromPosition(
                                    TextPosition(offset: sectionController.text.length),
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              final grade = gradeController.text.trim();
                              final section = sectionController.text.trim();
                              
                              if (grade.isNotEmpty && section.isNotEmpty) {
                                final newSectionName = '$grade - $section';
                                
                                if (isDuplicateSection(newSectionName)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Section "$newSectionName" already exists',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      backgroundColor: Colors.red,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }

                                setDialogState(() {
                                  sectionSchedules.add(SectionSchedule(
                                    section: newSectionName,
                                  ));
                                  gradeController.clear();
                                  sectionController.clear();
                                });
                              }
                            },
                            child: const Text('Add', style: TextStyle(fontSize: 14)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text('Existing Sections', 
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // List of existing sections
                      ListView.builder(
                        shrinkWrap: true,
                        itemCount: sectionSchedules.length,
                        itemBuilder: (context, index) {
                          final schedule = sectionSchedules[index];
                          return ExpansionTile(
                            title: Text(schedule.section),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.expand_more),
                              ],
                            ),
                            subtitle: Text(
                              schedule.classTime != null 
                                  ? '${schedule.classTime!.format(context)} • ${schedule.classDays.join(', ')}'
                                  : 'Schedule not set'
                            ),
                            children: [
                              ListTile(
                                title: const Text('Edit Schedule'),
                                leading: const Icon(Icons.edit),
                                onTap: () {
                                  Navigator.pop(context);
                                  _showEditScheduleDialog(schedule);
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(fontSize: 14)),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _saveSectionSchedules();
                    });
                    Navigator.pop(context);
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

  void _showFullScreenScheduleDialog(SectionSchedule schedule) {
    TimeOfDay? selectedTime = schedule.classTime;
    List<String> selectedDays = List.from(schedule.classDays);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            child: Scaffold(
              appBar: AppBar(
                title: Text('Set Schedule for ${schedule.section}', 
                  style: const TextStyle(fontSize: 18),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              body: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      title: const Text('Class Time'),
                      subtitle: Text(
                        selectedTime?.format(context) ?? 'Not set',
                        style: const TextStyle(fontSize: 14),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.access_time),
                        onPressed: () async {
                          final TimeOfDay? time = await showTimePicker(
                            context: context,
                            initialTime: selectedTime ?? TimeOfDay.now(),
                          );
                          if (time != null) {
                            setDialogState(() => selectedTime = time);
                          }
                        },
                      ),
                    ),
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Class Days', 
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
                            .map((day) => FilterChip(
                                  label: Text(day, style: const TextStyle(fontSize: 14)),
                                  selected: selectedDays.contains(day),
                                  onSelected: (bool selected) {
                                    setDialogState(() {
                                      if (selected) {
                                        selectedDays.add(day);
                                      } else {
                                        selectedDays.remove(day);
                                      }
                                    });
                                  },
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(fontSize: 14)),
                    ),
                    TextButton(
                      onPressed: () {
                        // Update the schedule
                        setState(() {
                          schedule.classTime = selectedTime;
                          schedule.classDays = selectedDays;
                          _saveSectionSchedules();
                        });
                        
                        // Show a success message
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Schedule saved successfully'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        
                        // Navigate back to the previous screen
                        Navigator.pop(context);
                        
                        // Show the manage sections dialog again
                        _showScheduleDialog();
                      },
                      child: const Text('Save', style: TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _deleteSection(SectionSchedule section) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 24),
            const SizedBox(width: 8),
            const Text('Delete Section', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are about to permanently delete:', 
              style: TextStyle(color: widget.isDarkMode ? Colors.white70 : Colors.black87)),
            const SizedBox(height: 10),
            _buildWarningItem('Section: ${section.section}', Colors.red),
            _buildWarningItem('All students in this section', Colors.red),
            _buildWarningItem('All attendance records', Colors.red),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'This action cannot be undone!',
                style: TextStyle(
                  color: Colors.red[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(
              color: widget.isDarkMode ? Colors.white70 : Colors.black87)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performSectionDeletion(section);
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningItem(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.remove_circle_outline, color: color, size: 18),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(
            color: color,
            fontSize: 14,
          )),
        ],
      ),
    );
  }

  void _performSectionDeletion(SectionSchedule section) {
    setState(() {
      recentlyDeletedSection = section;
      recentlyDeletedLearners = learners.where((learner) => learner.section == section.section).toList();
      sectionSchedules.remove(section);
      learners.removeWhere((learner) => learner.section == section.section);
      attendanceRecords.forEach((date, records) {
        records.removeWhere((learnerId, record) => learners.any((learner) => learner.id == learnerId));
      });
      _saveSectionSchedules();
      _saveLearners();
      _saveAttendanceRecords();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Section deleted'),
        action: SnackBarAction(
          label: 'Undo',
          textColor: widget.isDarkMode ? Colors.blue[200] : Colors.blue,
          onPressed: _undoDeleteSection,
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _undoDeleteSection() {
    if (recentlyDeletedSection != null) {
      setState(() {
        sectionSchedules.add(recentlyDeletedSection!);
        learners.addAll(recentlyDeletedLearners);
        _saveSectionSchedules();
        _saveLearners();
        recentlyDeletedSection = null;
        recentlyDeletedLearners.clear();
      });
    }
  }

  void _showEditScheduleDialog(SectionSchedule schedule) {
    TimeOfDay? selectedTime = schedule.classTime;
    List<String> selectedDays = List.from(schedule.classDays);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Scaffold(
              appBar: AppBar(
                title: Text('Edit ${schedule.section} Schedule'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      Navigator.pop(context); // Close edit dialog
                      _deleteSection(schedule); // Show deletion confirmation
                    },
                  ),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      title: const Text('Class Time'),
                      trailing: TextButton(
                        child: Text(
                          selectedTime != null 
                              ? selectedTime?.format(context) ?? 'Select Time'
                              : 'Select Time',
                          style: TextStyle(
                            color: selectedTime != null 
                                ? widget.isDarkMode ? Colors.white : Colors.black
                                : Colors.grey,
                          ),
                        ),
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: selectedTime ?? TimeOfDay.now(),
                          );
                          if (time != null) {
                            setDialogState(() => selectedTime = time);
                          }
                        },
                      ),
                    ),
                    const Divider(),
                    const Text('Class Days:', style: TextStyle(fontSize: 16)),
                    Wrap(
                      spacing: 8,
                      children: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
                          .map((day) => FilterChip(
                                label: Text(day),
                                selected: selectedDays.contains(day),
                                onSelected: (selected) {
                                  setDialogState(() {
                                    if (selected) {
                                      selectedDays.add(day);
                                    } else {
                                      selectedDays.remove(day);
                                    }
                                  });
                                },
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          schedule.classTime = selectedTime;
                          schedule.classDays = selectedDays;
                          _saveSectionSchedules();
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Schedule updated')),
                        );
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
