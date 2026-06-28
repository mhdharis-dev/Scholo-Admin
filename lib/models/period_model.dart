class PeriodSlotModel {
  final String periodName;
  final String type; // 'period' or 'break'
  final String startTime;
  final String endTime;
  final String? teacherName;
  final String? teacherId;
  final String? subject;
  final String? mainSubject;
  final int? colorValue; // Save Color as an integer

  const PeriodSlotModel({
    required this.periodName,
    required this.type,
    required this.startTime,
    required this.endTime,
    this.teacherName,
    this.teacherId,
    this.subject,
    this.mainSubject,
    this.colorValue,
  });

  PeriodSlotModel copyWith({
    String? periodName,
    String? type,
    String? startTime,
    String? endTime,
    String? teacherName,
    String? teacherId,
    String? subject,
    String? mainSubject,
    int? colorValue,
  }) {
    return PeriodSlotModel(
      periodName: periodName ?? this.periodName,
      type: type ?? this.type,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      teacherName: teacherName ?? this.teacherName,
      teacherId: teacherId ?? this.teacherId,
      subject: subject ?? this.subject,
      mainSubject: mainSubject ?? this.mainSubject,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'periodName': periodName,
      'type': type,
      'startTime': startTime,
      'endTime': endTime,
      'teacherName': teacherName,
      'teacherId': teacherId,
      'subject': subject,
      'mainSubject': mainSubject,
      'colorValue': colorValue,
    };
  }

  factory PeriodSlotModel.fromMap(Map<String, dynamic> map) {
    return PeriodSlotModel(
      periodName: map['periodName'] ?? '',
      type: map['type'] ?? 'period',
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
      teacherName: map['teacherName'] as String?,
      teacherId: map['teacherId'] as String?,
      subject: map['subject'] as String?,
      mainSubject: map['mainSubject'] as String?,
      colorValue: map['colorValue'] as int?,
    );
  }
}