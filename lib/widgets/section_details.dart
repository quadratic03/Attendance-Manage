import 'package:flutter/material.dart';
import '../models/section_schedule.dart'; // Ensure this file exists

class SectionDetails extends StatelessWidget {
  final SectionSchedule section;

  SectionDetails({required this.section});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(section.name),
      ),
      body: Center(
        child: Text('Details for ${section.name}'),
      ),
    );
  }
}
