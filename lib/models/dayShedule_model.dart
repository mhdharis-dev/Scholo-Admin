import 'package:scholo_admin/models/period_model.dart';

class DayScheduleModel {
  final String status; // 'Working Day' or 'Non-Working Day'
  final int totalPeriods;
  final List<PeriodSlotModel> periods;

  const DayScheduleModel({
    required this.status,
    required this.totalPeriods,
    required this.periods,
  });

  DayScheduleModel copyWith({
    String? status,
    int? totalPeriods,
    List<PeriodSlotModel>? periods,
  }) {
    return DayScheduleModel(
      status: status ?? this.status,
      totalPeriods: totalPeriods ?? this.totalPeriods,
      periods: periods ?? this.periods,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'totalPeriods': totalPeriods,
      // FIX: Convert the list of custom models into a list of maps
      'periods': periods.map((p) => p.toMap()).toList(),
    };
  }

  factory DayScheduleModel.fromMap(Map<String, dynamic> map) {
    return DayScheduleModel(
      status: map['status'] ?? 'Non-Working Day',
      totalPeriods: map['totalPeriods'] ?? 0,
      // FIX: Map over the dynamic list from Firestore and convert each item
      periods: List<PeriodSlotModel>.from(
        (map['periods'] ?? []).map((x) => PeriodSlotModel.fromMap(x)),
      ),
    );
  }
}