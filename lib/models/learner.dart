import 'package:hive/hive.dart';

class Learner extends HiveObject {
  final String id;
  String name;
  String section;
  bool isPriority;

  Learner({
    required this.id,
    required this.name,
    required this.section,
    this.isPriority = false,
  });

  factory Learner.fromJson(Map<String, dynamic> json) {
    return Learner(
      id: json['id'],
      name: json['name'],
      section: json['section'],
      isPriority: json['isPriority'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'section': section,
      'isPriority': isPriority,
    };
  }
}

enum AttendanceStatus { present, late, absent, unchecked }