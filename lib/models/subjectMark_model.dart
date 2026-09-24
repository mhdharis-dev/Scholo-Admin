class SubjectMarkModel {
  String subject;
  int maxMarks;
  int obtained;
  int ceMaxMarks;
  int ceObtained;
  String grade;

  //<editor-fold desc="Data Methods">
  SubjectMarkModel({
    required this.subject,
    required this.maxMarks,
    required this.obtained,
    this.ceMaxMarks = 0,
    this.ceObtained = 0,
    required this.grade,
  });

  SubjectMarkModel copyWith({
    String? subject,
    int? maxMarks,
    int? obtained,
    int? ceMaxMarks,
    int? ceObtained,
    String? grade,
  }) {
    return SubjectMarkModel(
      subject: subject ?? this.subject,
      maxMarks: maxMarks ?? this.maxMarks,
      obtained: obtained ?? this.obtained,
      ceMaxMarks: ceMaxMarks ?? this.ceMaxMarks,
      ceObtained: ceObtained ?? this.ceObtained,
      grade: grade ?? this.grade,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subject': subject,
      'maxMarks': maxMarks,
      'obtained': obtained,
      'ceTotal': ceMaxMarks,
      'ceObtained': ceObtained,
      'grade': grade,
    };
  }

  factory SubjectMarkModel.fromMap(Map<String, dynamic> map) {
    return SubjectMarkModel(
      subject: map['subject'] as String? ?? '',
      maxMarks: (map['maxMarks'] as num?)?.toInt() ?? 0,
      obtained: (map['obtained'] as num?)?.toInt() ?? 0,
      ceMaxMarks: (map['ceTotal'] as num?)?.toInt() ?? (map['ceMaxMarks'] as num?)?.toInt() ?? (map['ceTotalMark'] as num?)?.toInt() ?? 0,
      ceObtained: (map['ceObtained'] as num?)?.toInt() ?? (map['ceObtainedMark'] as num?)?.toInt() ?? 0,
      grade: map['grade'] as String? ?? '',
    );
  }

  //</editor-fold>
}
