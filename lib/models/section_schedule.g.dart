// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'section_schedule.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SectionScheduleAdapter extends TypeAdapter<SectionSchedule> {
  @override
  final int typeId = 1;

  @override
  SectionSchedule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SectionSchedule(
      section: fields[0] as String,
      classTime: fields[1] as TimeOfDay?,
      classDays: (fields[2] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, SectionSchedule obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.section)
      ..writeByte(1)
      ..write(obj.classTime)
      ..writeByte(2)
      ..write(obj.classDays);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SectionScheduleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
