class PeriodSlotModel {
  final String periodName;
  final String type; // 'period' or 'break'
  final String startTime;
  final String endTime;
  final String? teacherName;
  final String? teacherId;
  final String? subject;
  final int? colorValue; // Save Color as an integer

  const PeriodSlotModel({
    required this.periodName,
    required this.type,
    required this.startTime,
    required this.endTime,
    this.teacherName,
    this.teacherId,
    this.subject,
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
      'colorValue': colorValue,
    };
  }

  factory PeriodSlotModel.fromMap(Map<String, dynamic> map) {
    return PeriodSlotModel(
      periodName: map['periodName'] ?? '',
      type: map['type'] ?? 'period',
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
      // FIX: Use 'as String?' so it doesn't crash if the value is null
      teacherName: map['teacherName'] as String?,
      teacherId: map['teacherId'] as String?,
      subject: map['subject'] as String?,
      colorValue: map['colorValue'] as int?,
    );
  }
}