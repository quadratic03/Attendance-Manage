// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learner.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LearnerAdapter extends TypeAdapter<Learner> {
  @override
  final int typeId = 0;

  @override
  Learner read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Learner(
      id: fields[0] as String,
      name: fields[1] as String,
      section: fields[2] as String,
      isPriority: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Learner obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.section)
      ..writeByte(3)
      ..write(obj.isPriority);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LearnerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
