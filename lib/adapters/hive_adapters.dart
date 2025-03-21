import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/learner.dart';
import '../models/section_schedule.dart';

class LearnerAdapter extends TypeAdapter<Learner> {
  @override
  final int typeId = 0;

  @override
  Learner read(BinaryReader reader) {
    return Learner(
      id: reader.readString(),
      name: reader.readString(),
      section: reader.readString(),
      isPriority: reader.readBool(),
    );
  }

  @override
  void write(BinaryWriter writer, Learner obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeString(obj.section);
    writer.writeBool(obj.isPriority);
  }
}

class SectionScheduleAdapter extends TypeAdapter<SectionSchedule> {
  @override
  final int typeId = 1;

  @override
  SectionSchedule read(BinaryReader reader) {
    return SectionSchedule(
      section: reader.readString(),
      classTime: reader.readBool() // Check if classTime exists
          ? TimeOfDay(hour: reader.readByte(), minute: reader.readByte())
          : null,
      classDays: reader.readStringList(),
    );
  }

  @override
  void write(BinaryWriter writer, SectionSchedule obj) {
    writer.writeString(obj.section);
    if (obj.classTime != null) {
      writer.writeBool(true); // Indicate classTime is present
      writer.writeByte(obj.classTime!.hour);
      writer.writeByte(obj.classTime!.minute);
    } else {
      writer.writeBool(false); // Indicate classTime is null
    }
    writer.writeStringList(obj.classDays);
  }
}

class TimeOfDayAdapter extends TypeAdapter<TimeOfDay> {
  @override
  final int typeId = 2;

  @override
  TimeOfDay read(BinaryReader reader) {
    final hour = reader.readByte();
    final minute = reader.readByte();
    return TimeOfDay(hour: hour, minute: minute);
  }

  @override
  void write(BinaryWriter writer, TimeOfDay obj) {
    writer.writeByte(obj.hour);
    writer.writeByte(obj.minute);
  }
}