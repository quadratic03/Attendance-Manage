import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/learner.dart';
import 'models/section_schedule.dart';
import 'adapters/hive_adapters.dart';
import 'widgets/landing_page.dart';
import 'widgets/attendance_manager.dart';
import 'widgets/reports_tab.dart';
import 'models/styling_classes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Hive.initFlutter();
    Hive
      ..registerAdapter(LearnerAdapter())
      ..registerAdapter(SectionScheduleAdapter())
      ..registerAdapter(TimeOfDayAdapter());

    // Comment out these lines after running once to reset data
    // await Hive.deleteBoxFromDisk('learners');
    // await Hive.deleteBoxFromDisk('sectionSchedules');
    // await Hive.deleteBoxFromDisk('attendanceRecords');
    // await Hive.deleteBoxFromDisk('settings');

    await Hive.openBox<Learner>('learners');
    await Hive.openBox<SectionSchedule>('sectionSchedules');
    await Hive.openBox<Map>('attendanceRecords');
    await Hive.openBox<bool>('settings');

    runApp(const DepEdAttendanceApp());
  } catch (e) {
    // Log the error or handle it appropriately
    print('Error during initialization: $e');
  }
}

class DepEdAttendanceApp extends StatefulWidget {
  const DepEdAttendanceApp({super.key});

  @override
  _DepEdAttendanceAppState createState() => _DepEdAttendanceAppState();
}

class _DepEdAttendanceAppState extends State<DepEdAttendanceApp> {
  bool _isDarkMode = false;
  bool _showAnimation = false;

  final Map<String, Map<String, Map<String, dynamic>>> _attendanceRecords = {};
  final List<SectionSchedule> _sectionSchedules = [];
  final List<Learner> _learners = [];

  Map<String, Map<String, Map<String, dynamic>>> get attendanceRecords => _attendanceRecords;
  List<SectionSchedule> get sectionSchedules => _sectionSchedules;
  List<Learner> get learners => _learners;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final settingsBox = Hive.box<bool>('settings');
    setState(() {
      _isDarkMode = settingsBox.get('isDarkMode', defaultValue: false) ?? false;
    });
  }

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
      _showAnimation = true;
      Hive.box<bool>('settings').put('isDarkMode', _isDarkMode);
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _showAnimation = false;
        });
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Student Attendance Manager',
      theme: _isDarkMode
          ? ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF424242),
              primaryColor: const Color(0xFFFFB300),
              appBarTheme: const AppBarTheme(
                elevation: 4,
                backgroundColor: Color(0xFF616161),
                foregroundColor: Colors.white,
                titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              colorScheme: ColorScheme.fromSwatch(
                primarySwatch: Colors.amber,
                accentColor: const Color(0xFFFFC107),
                backgroundColor: const Color(0xFF424242),
              ).copyWith(brightness: Brightness.dark),
              textTheme: const TextTheme(
                headlineSmall: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                bodyMedium: TextStyle(color: Colors.white),
                labelMedium: TextStyle(color: Colors.white),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB300),
                  foregroundColor: Colors.black,
                ),
              ),
              floatingActionButtonTheme: const FloatingActionButtonThemeData(
                backgroundColor: Color(0xFFFFB300),
                foregroundColor: Colors.black,
              ),
              dialogBackgroundColor: const Color(0xFF616161),
            )
          : ThemeData(
              brightness: Brightness.light,
              scaffoldBackgroundColor: const Color(0xFFF5F5F5),
              primaryColor: const Color(0xFF26A69A),
              appBarTheme: const AppBarTheme(
                elevation: 4,
                backgroundColor: Color(0xFF26A69A),
                foregroundColor: Colors.black,
                titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              colorScheme: ColorScheme.fromSwatch(
                primarySwatch: Colors.teal,
                accentColor: const Color(0xFFFFC107),
                backgroundColor: const Color(0xFFF5F5F5),
              ),
              textTheme: const TextTheme(
                headlineSmall: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                bodyMedium: TextStyle(color: Colors.black),
                labelMedium: TextStyle(color: Colors.black),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF26A69A),
                  foregroundColor: Colors.white,
                ),
              ),
              floatingActionButtonTheme: const FloatingActionButtonThemeData(
                backgroundColor: Color(0xFF26A69A),
                foregroundColor: Colors.white,
              ),
              dialogBackgroundColor: const Color(0xFFF5F5F5),
            ),
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox(),
            if (_showAnimation)
              AnimatedOpacity(
                opacity: _showAnimation ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 1500),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: _isDarkMode
                          ? [Colors.black87, Colors.black54]
                          : [Colors.white70, Colors.white30],
                      center: Alignment.center,
                      radius: 1.5,
                    ),
                  ),
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 1000),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Transform.rotate(
                            angle: value * 2 * 3.14159,
                            child: Icon(
                              _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                              size: 100,
                              color: _isDarkMode ? Colors.amber : Colors.orange,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      home: LandingPageChecker(onThemeToggle: _toggleTheme, isDarkMode: _isDarkMode),
      routes: {
        '/reports': (context) => ReportsTab(
          attendanceRecords: attendanceRecords,
          sectionSchedules: sectionSchedules,
          learners: learners,
          selectedDate: DateTime.now(),
          isDarkMode: _isDarkMode,
          textColor: _isDarkMode ? Colors.white : Colors.black,
          itemStyling: ItemStyling(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            sectionHeaderBackground: Theme.of(context).primaryColor,
            listItemBorder: Theme.of(context).dividerColor,
            cardBackground: Theme.of(context).cardColor,
          ),
        ),
      },
    );
  }
}

class LandingPageChecker extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDarkMode;

  const LandingPageChecker({super.key, required this.onThemeToggle, required this.isDarkMode});

  @override
  _LandingPageCheckerState createState() => _LandingPageCheckerState();
}

class _LandingPageCheckerState extends State<LandingPageChecker> {
  bool hasSeenLandingPage = false;
  List<Learner> learners = [];
  List<SectionSchedule> sectionSchedules = [];
  Map<String, Map<String, Map<String, dynamic>>> attendanceRecords = {};

  @override
  void initState() {
    super.initState();
    _checkLandingPageStatus();
  }

  Future<void> _checkLandingPageStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool hasSeen = prefs.getBool('hasSeenLandingPage') ?? false;
    setState(() {
      hasSeenLandingPage = hasSeen;
    });
  }

  Future<void> _setHasSeenLandingPage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenLandingPage', true);
    setState(() {
      hasSeenLandingPage = true;
    });
  }
  @override
  Widget build(BuildContext context) {
    if (hasSeenLandingPage) {
      return AttendanceManager(
        onThemeToggle: widget.onThemeToggle,
        isDarkMode: widget.isDarkMode,
        attendanceRecords: attendanceRecords,
        sectionSchedules: sectionSchedules,
        learners: learners,
        itemStyling: ItemStyling(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          sectionHeaderBackground: Theme.of(context).primaryColor,
          listItemBorder: Theme.of(context).dividerColor,
          cardBackground: Theme.of(context).cardColor,
        ),
        tutorialStep: 0,
      );
    } else {
      return LandingPage(
        onGetStarted: _setHasSeenLandingPage,
        onThemeToggle: widget.onThemeToggle,
        isDarkMode: widget.isDarkMode,
      );
    }
  }
}