class SubjectMarkModel {
  String subject;
  int maxMarks;
  int obtained;
  String grade;

  //<editor-fold desc="Data Methods">
  SubjectMarkModel({
    required this.subject,
    required this.maxMarks,
    required this.obtained,
    required this.grade,
  });

  SubjectMarkModel copyWith({
    String? subject,
    int? maxMarks,
    int? obtained,
    String? grade,
  }) {
    return SubjectMarkModel(
      subject: subject ?? this.subject,
      maxMarks: maxMarks ?? this.maxMarks,
      obtained: obtained ?? this.obtained,
      grade: grade ?? this.grade,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subject': subject,
      'maxMarks': maxMarks,
      'obtained': obtained,
      'grade': grade,
    };
  }

  factory SubjectMarkModel.fromMap(Map<String, dynamic> map) {
    return SubjectMarkModel(
      subject: map['subject'] as String,
      maxMarks: map['maxMarks'] as int,
      obtained: map['obtained'] as int,
      grade: map['grade'] as String,
    );
  }

  //</editor-fold>
}
