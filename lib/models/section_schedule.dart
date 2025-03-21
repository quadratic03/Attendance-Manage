import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class SectionSchedule extends HiveObject {
  String section;
  TimeOfDay? classTime;
  List<String> classDays;
  final String name;

  SectionSchedule({
    required this.section,
    this.classTime,
    this.classDays = const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
    required this.name,
  });
}