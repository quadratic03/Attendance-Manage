import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart'; // Add this import
import '../models/learner.dart';
import '../models/section_schedule.dart';
import 'dart:math';
import 'package:flutter/rendering.dart' as ui;

class SectionAttendancePage extends StatefulWidget {
  final SectionSchedule section;
  final List<Learner> learners;
  final Map<String, Map<String, Map<String, dynamic>>> attendanceRecords;
  final DateTime selectedDate;
  final Function(String, AttendanceStatus) onAttendanceChanged;
  final VoidCallback onSaveAttendance;
  final Box<Map> attendanceRecordsBox; // Add this field

  const SectionAttendancePage({
    super.key,
    required this.section,
    required this.learners,
    required this.attendanceRecords,
    required this.selectedDate,
    required this.onAttendanceChanged,
    required this.onSaveAttendance,
    required this.attendanceRecordsBox, // Add this parameter
  });

  @override
  _SectionAttendancePageState createState() => _SectionAttendancePageState();
}

class _SectionAttendancePageState extends State<SectionAttendancePage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late List<Learner> filteredLearners;
  late int totalStudents;
  int _titleTapCount = 0;
  bool _showBubbles = false;
  final List<Particle> _particles = [];
  final Random _random = Random();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    filteredLearners = widget.learners.where((l) => l.section == widget.section.section).toList();
    totalStudents = filteredLearners.length;
    _searchController.addListener(_filterLearners);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    )..addListener(() {
        if (_showBubbles) {
          setState(() {
            for (var particle in _particles) {
              particle.update();
            }
            _particles.removeWhere((particle) => particle.alpha <= 0);
          });
        }
      });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoMarkAllPresent();
    });
  }

  void _autoMarkAllPresent() {
    String dateKey = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    widget.attendanceRecords.putIfAbsent(dateKey, () => {});

    setState(() {
      for (var learner in filteredLearners) {
        // Mark as Present if no existing record (or force it if desired)
        if (!widget.attendanceRecords[dateKey]!.containsKey(learner.id)) {
          widget.attendanceRecords[dateKey]![learner.id] = {
            'status': AttendanceStatus.present,
            'time': DateTime.now(),
          };
          widget.onAttendanceChanged(learner.id, AttendanceStatus.present);
        }
      }
    });
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

  void _handleTitleTap() {
    _titleTapCount++;
    if (_titleTapCount == 10) {
      setState(() {
        _showBubbles = true;
        _createParticles();
      });
      _animationController.repeat();
      
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _animationController.stop();
          setState(() {
            _showBubbles = false;
            _titleTapCount = 0;
            _particles.clear();
          });
        }
      });
    }
  }

  void _createParticles() {
    final size = MediaQuery.of(context).size;
    for (int i = 0; i < 100; i++) {
      _particles.add(
        Particle(
          x: size.width / 2,
          y: size.height / 2,
          velocityX: (_random.nextDouble() - 0.5) * 15,
          velocityY: (_random.nextDouble() - 0.5) * 15,
          size: _random.nextDouble() * 20 + 5,
          color: Color.fromARGB(
            255,
            _random.nextInt(256),
            _random.nextInt(256),
            _random.nextInt(256),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String dateKey = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final cardColor = isDarkMode ? const Color(0xFF2C2C2C) : Colors.white;
    final dividerColor = isDarkMode ? Colors.white24 : Colors.black12;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _handleTitleTap,
          child: Text('${widget.section.section} - Total Students: $totalStudents'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: widget.onSaveAttendance,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Search',
                    labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                    prefixIcon: Icon(Icons.search, color: textColor.withOpacity(0.7)),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Theme.of(context).primaryColor),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filteredLearners.length,
                  itemBuilder: (context, index) {
                    final learner = filteredLearners[index];
                    Map<String, dynamic>? record = widget.attendanceRecords[dateKey]?[learner.id];
                    AttendanceStatus status = record?['status'] ?? AttendanceStatus.unchecked;

                    return Card(
                      color: cardColor,
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        title: Text(
                          '${index + 1}. ${learner.name}',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildAttendanceButton(
                              status: status,
                              currentStatus: AttendanceStatus.present,
                              icon: Icons.check_circle_outline,
                              learner: learner,
                              isDarkMode: isDarkMode,
                            ),
                            const SizedBox(width: 8),
                            _buildAttendanceButton(
                              status: status,
                              currentStatus: AttendanceStatus.late,
                              icon: Icons.access_time,
                              learner: learner,
                              isDarkMode: isDarkMode,
                            ),
                            const SizedBox(width: 8),
                            _buildAttendanceButton(
                              status: status,
                              currentStatus: AttendanceStatus.absent,
                              icon: Icons.cancel_outlined,
                              learner: learner,
                              isDarkMode: isDarkMode,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          if (_showBubbles)
            CustomPaint(
              painter: ParticlePainter(_particles),
              size: MediaQuery.of(context).size,
            ),
        ],
      ),
    );
  }

  Widget _buildAttendanceButton({
    required AttendanceStatus status,
    required AttendanceStatus currentStatus,
    required IconData icon,
    required Learner learner,
    required bool isDarkMode,
  }) {
    final isSelected = status == currentStatus;
    final color = _getStatusColor(currentStatus);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          _updateAttendanceStatus(
            learner.id,
            isSelected ? AttendanceStatus.unchecked : currentStatus,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? color : color.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            color: isSelected ? color : color.withOpacity(0.5),
            size: 24,
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(AttendanceStatus status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (status) {
      case AttendanceStatus.present:
        return isDark ? Colors.greenAccent : Colors.green;
      case AttendanceStatus.late:
        return isDark ? Colors.amberAccent : Colors.amber;
      case AttendanceStatus.absent:
        return isDark ? Colors.redAccent : Colors.red;
      default:
        return isDark ? Colors.grey[400]! : Colors.grey[600]!;
    }
  }

  void _updateAttendanceStatus(String learnerId, AttendanceStatus newStatus) {
    String dateKey = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    setState(() {
      widget.attendanceRecords.putIfAbsent(dateKey, () => {});
      widget.attendanceRecords[dateKey]![learnerId] = {
        'status': newStatus,
        'time': DateTime.now(),
      };
      widget.onAttendanceChanged(learnerId, newStatus);
      // Save attendance records
      _saveAttendanceRecords();
    });
  }

  Future<void> _saveAttendanceRecords() async {
    await widget.attendanceRecordsBox.put(
      'records',
      widget.attendanceRecords.map(
        (date, records) => MapEntry(
          date,
          records.map(
            (id, record) => MapEntry(
              id,
              {
                'status': record['status'].toString(),
                'time': record['time'].toIso8601String(),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class Particle {
  double x;
  double y;
  double velocityX;
  double velocityY;
  double size;
  double alpha;
  final Color color;

  Particle({
    required this.x,
    required this.y,
    required this.velocityX,
    required this.velocityY,
    required this.size,
    required this.color,
  }) : alpha = 1.0;

  void update() {
    x += velocityX;
    y += velocityY;
    velocityY += 0.1; // Add gravity effect
    size *= 0.99; // Slowly shrink
    alpha *= 0.97; // Fade out
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final Paint particlePaint = Paint()..style = PaintingStyle.fill;

  ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      // Draw main particle
      particlePaint.color = particle.color.withOpacity(particle.alpha);
      canvas.drawCircle(
        Offset(particle.x, particle.y),
        particle.size,
        particlePaint,
      );

      // Draw shine effect
      final shinePaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withOpacity(particle.alpha * 0.5);
      canvas.drawCircle(
        Offset(particle.x - particle.size * 0.3, particle.y - particle.size * 0.3),
        particle.size * 0.2,
        shinePaint,
      );
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => true;
}